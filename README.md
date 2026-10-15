# React + Docker Hub + VM con GitHub Actions

Este repositorio usa el proyecto Vite/React de `contenedores`. Cada cambio en `main` (o una ejecución manual desde **Actions**) hace lo siguiente:

1. Instala dependencias, ejecuta el linter y compila React.
2. Construye la imagen y la publica en Docker Hub como `USUARIO/mi-web-plana:latest` y `USUARIO/mi-web-plana:SHA_DEL_COMMIT`.
3. Entra por SSH a `147.15.84.247`, descarga la imagen del commit y reemplaza el contenedor que publica el puerto 80.
4. Comprueba la salud del contenedor. Si falla, vuelve a iniciar el contenedor anterior.

## Preparación inicial

En la VM debe existir Docker y el usuario de SSH debe poder ejecutar `docker info` sin `sudo` ni contraseña interactiva. El puerto 80 debe estar permitido en las reglas de red de Oracle Cloud y en el firewall del sistema. El acceso SSH debe estar permitido desde los runners de GitHub, o debe usarse un runner propio con acceso a la VM.

La imagen `USUARIO/mi-web-plana` debe ser **pública** en Docker Hub para que la VM pueda descargarla sin guardar una credencial allí. Si se quiere privada, hay que hacer `docker login` en la VM con una credencial de solo lectura antes de ejecutar Actions.

En **GitHub → Settings → Secrets and variables → Actions → Repository secrets**, configurar:

| Nombre | Valor |
| --- | --- |
| `DOCKER_USERNAME` | Usuario de Docker Hub. |
| `DOCKER_PASSWORD` | Un token de Docker Hub nuevo con permiso de escritura. |
| `VM_SSH_USER` | Usuario Linux con acceso SSH a la VM. |
| `VM_SSH_PRIVATE_KEY` | Contenido de una clave privada SSH autorizada en la VM. |
| `VM_SSH_KNOWN_HOSTS` | Línea de `known_hosts` de la VM, tras verificar su huella con un canal confiable. |

El token de Docker Hub compartido en el chat quedó expuesto. Se recomienda revocarlo y actualizar `DOCKER_PASSWORD`. Nunca agregar el token ni la clave SSH al repositorio.

Para obtener el formato de `VM_SSH_KNOWN_HOSTS`, ejecutar localmente `ssh-keyscan -p 22 147.15.84.247`. **Antes de guardarlo**, comparar la huella con la clave de host obtenida dentro de la VM o desde una consola confiable. No confiar únicamente en la salida de `ssh-keyscan`.

Opcionalmente, en **Repository variables**, configurar `VM_SSH_PORT` si SSH no usa el puerto 22 y `VM_HTTP_PORT` si la web debe publicarse en un puerto distinto del 80.

El script de despliegue reemplaza un contenedor Docker existente que publique el puerto solicitado. Si ese puerto lo ocupa un proceso del sistema, como Nginx instalado directamente en la VM, el despliegue fallará y será necesario liberar el puerto una sola vez. El script está en [`.github/scripts/deploy-vm.sh`](.github/scripts/deploy-vm.sh).

## Uso

Hacer `git push origin main` o elegir **Actions → Publicar React y desplegar en la VM → Run workflow**. La aplicación quedará en `http://147.15.84.247/` cuando `VM_HTTP_PORT` sea 80.

Para probarla localmente:

```bash
npm ci
npm run lint
npm run build
docker build -t react-vm .
docker run --rm -p 8080:80 react-vm
```

Abrir `http://localhost:8080/`.
