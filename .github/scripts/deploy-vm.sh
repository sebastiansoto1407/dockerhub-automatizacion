#!/usr/bin/env bash
set -Eeuo pipefail

image="${1:?Falta la imagen de Docker Hub}"
host_port="${2:-80}"
container_name=react-vm

if [[ ! "$host_port" =~ ^[0-9]+$ ]] || (( host_port < 1 || host_port > 65535 )); then
  echo "Puerto HTTP inválido: $host_port" >&2
  exit 1
fi

command -v docker >/dev/null || { echo 'Docker no está instalado en la VM' >&2; exit 1; }
docker info >/dev/null || { echo 'El usuario SSH no puede usar Docker' >&2; exit 1; }
docker pull "$image"

# Conservar el contenedor anterior hasta comprobar que la versión nueva funciona.
old_container=''
old_stopped=0
old_renamed=0
replace_started=0
deployed=0

cleanup() {
  status=$?
  trap - EXIT
  if (( deployed == 0 )); then
    if (( replace_started == 1 )); then
      docker rm -f "$container_name" >/dev/null 2>&1 || true
    fi
    if (( old_stopped == 1 )); then
      if (( old_renamed == 1 )); then
        docker rename "$old_container" "$container_name" || true
      fi
      echo 'Restaurando el contenedor anterior'
      docker start "$old_container" || true
    fi
  fi
  exit "$status"
}
trap cleanup EXIT

while IFS= read -r id; do
  [[ -n "$id" ]] || continue
  if docker port "$id" 2>/dev/null | grep -Eq ":[[:space:]]*${host_port}$"; then
    if [[ -n "$old_container" ]]; then
      echo "Hay varios contenedores publicados en el puerto $host_port" >&2
      exit 1
    fi
    old_container="$id"
  fi
done < <(docker ps --no-trunc -q)

if [[ -n "$old_container" ]]; then
  echo "Deteniendo el contenedor anterior: $old_container"
  docker stop "$old_container"
  old_stopped=1
fi

if docker container inspect "$container_name" >/dev/null 2>&1; then
  current_id="$(docker container inspect --format '{{.Id}}' "$container_name")"
  if [[ "$current_id" == "$old_container" ]]; then
    docker rename "$container_name" "${container_name}-previous-$(date +%s)"
    old_renamed=1
  else
    echo "Ya existe $container_name, pero no está en el puerto $host_port" >&2
    exit 1
  fi
fi

replace_started=1
docker run -d \
  --name "$container_name" \
  --restart unless-stopped \
  --publish "$host_port:80" \
  "$image"

for attempt in {1..20}; do
  health="$(docker inspect --format '{{.State.Health.Status}}' "$container_name" 2>/dev/null || true)"
  if [[ "$health" == healthy ]]; then
    echo "Despliegue correcto: $image en el puerto $host_port"
    deployed=1
    if [[ -n "$old_container" ]]; then docker rm "$old_container" || true; fi
    exit 0
  fi
  if [[ "$health" == unhealthy ]]; then break; fi
  sleep 2
done

echo 'El nuevo contenedor no pasó la verificación de salud' >&2
docker logs --tail 50 "$container_name" >&2 || true
exit 1
