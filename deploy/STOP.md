# Как остановить локальный YTsaurus и не потерять данные

Кластер состоит из двух контейнеров (их создаёт [`start.sh`](./start.sh)):

| Контейнер     | Что внутри                                                                   | RAM (замерено) |
|---------------|------------------------------------------------------------------------------|----------------|
| `yt.backend`  | мастер, нода, планировщик, controller agent, HTTP-прокси, Query Tracker, YQL-агент | ~2,2 ГБ   |
| `yt.frontend` | веб-интерфейс (http://localhost:18001)                                       | ~0,2 ГБ        |

Остальные контейнеры (`gitlab`, `gitlab-runner-1`) к домашке не относятся, их **не трогаем**.

## Где лежат данные

Рабочая директория кластера (`/tmp/locasaurus` внутри контейнера: состояние мастера, чанки таблиц, логи)
смонтирована из именованного Docker volume **`ytsaurus-locasaurus-data`**. Поэтому данные не зависят
от жизни контейнера.

## 1. Остановить и запустить снова (данные сохраняются)

```bash
./deploy/stop.sh     # docker stop обоих контейнеров, RAM освобождается
./deploy/start.sh    # контейнеры уже есть -> docker start; готово за ~2-4 минуты под эмуляцией
```

Проверено: после `stop.sh` + `start.sh` на месте `//home/mbogomazov/{books,sonnets,word_count,word_index}`,
`lookup-rows` находит строку, YQL-запрос по строке 7 возвращает те же 6 слов.

### Почему понадобился `yt_local_restartable.py`

`yt_local start` умеет переиспользовать существующую рабочую директорию, но компоненты Query Tracker и
YQL-агент написаны в расчёте на «чистый» кластер. На повторном старте они падали:

- `FileExistsError: ... bin/ytserver-query-tracker` — симлинк создаётся без проверки
  (точка входа контейнера удаляет его перед стартом);
- `User "query_tracker" already exists`, `Member "query_tracker" is already present in group "superusers"` —
  объекты уже есть в мастере. [`yt_local_restartable.py`](./yt_local_restartable.py) оборачивает клиент так,
  что `create`/`add_member` игнорируют ошибки «already exists / already present», и запускает оригинальный
  `yt_local` без изменений.

Файл монтируется в контейнер из репозитория, поэтому **не переносите папку репозитория**, пока контейнеры
существуют (или пересоздайте их: см. п. 2).

## 2. Удалить контейнеры, но сохранить данные

```bash
./deploy/stop.sh
docker rm yt.frontend yt.backend
./deploy/start.sh    # создаст контейнеры заново поверх того же volume — таблицы на месте
```

## 3. Полностью удалить кластер вместе с данными

```bash
./deploy/stop.sh
docker rm yt.frontend yt.backend
docker volume rm ytsaurus-locasaurus-data                             # ВСЕ таблицы пропадут
docker network rm yt_local_cluster_network
docker rmi ghcr.io/ytsaurus/local:stable ghcr.io/ytsaurus/ui:stable   # ~7 ГБ образов (по желанию)
```

Восстановить всё с нуля: `./deploy/start.sh`, затем `bash scripts/run_all.sh`.

## Если не стартует

```bash
docker logs yt.backend 2>&1 | grep -v '^    ' | tail -30
```

- Под большой нагрузкой на машину (load average 20+) компоненты не успевают стартовать: `Scheduler still not ready`,
  `No healthy tablet cells in bundle "default"`. Обычно достаточно просто ещё раз запустить `./deploy/start.sh`
  (проверено). Если не помогло — дождаться, пока нагрузка спадёт, `docker rm yt.backend` и снова `./deploy/start.sh`
  (данные в volume не трогаются).
- Первые запросы сразу после старта могут идти с `WARNING ... timed out` и ретраями — таблетки прогреваются,
  через минуту всё работает без предупреждений.
- Если на повторном старте появилась новая ошибка вида «already exists» с другой формулировкой — добавить
  её текст в `ALREADY_DONE_MARKERS` в `yt_local_restartable.py`.

## Проверка

```bash
docker ps -a --filter name=yt.          # статус контейнеров
docker volume ls | grep ytsaurus         # volume с данными
docker stats --no-stream                 # сколько памяти занимают запущенные контейнеры
```
