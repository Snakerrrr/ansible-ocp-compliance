# GUÍA DE ACTUALIZACIÓN EN AAP

Checklist para actualizar la configuración en Ansible Automation Platform (AAP) tras el cambio de **entrega por correo (SMTP)** a **push a GitLab** en el orquestador multicluster.

---

## 1. Variables a ELIMINAR en AAP

Eliminar del **Job Template** (Extra Variables o Survey) y de cualquier **Credential Type** o **Environment** asociado las siguientes variables:

| Variable | Descripción |
|----------|-------------|
| `do_send_email` | Flag que activaba el envío por correo (reemplazado por `do_push_gitlab`) |
| `email_smtp_host` | Servidor SMTP |
| `email_smtp_port` | Puerto SMTP (ej: 587) |
| `email_smtp_username` | Usuario SMTP |
| `email_smtp_password` | Contraseña SMTP |
| `email_smtp_timeout` | Timeout SMTP en segundos |
| `email_from` | Remitente del correo |
| `email_to` | Destinatario(s) del correo |
| `email_subject_prefix` | Prefijo del asunto del correo |

**Surveys:** Si tenías preguntas (Survey) para “Destinatario de correo”, “Host SMTP”, “Usuario SMTP”, etc., **elimínalas**.

**Environment Variables** (inyección desde credenciales): Si usabas un Credential Type que inyectaba `EMAIL_SMTP_PASSWORD`, `EMAIL_SMTP_USERNAME`, `EMAIL_FROM`, `EMAIL_TO`, deja de usarlo o elimina esas entradas del injector.

---

## 2. Variables a AGREGAR en AAP

Crear en el **Job Template** (Extra Variables o Survey) las siguientes variables:

| Variable | Tipo | Obligatorio si `do_push_gitlab=true` | Descripción | Ejemplo |
|----------|------|--------------------------------------|-------------|---------|
| `do_push_gitlab` | boolean | Sí (para subir reportes) | Activa el push de reportes al repositorio GitLab | `true` |
| `gitlab_repo_url` | string | Sí | URL HTTPS del repositorio GitLab | `https://gitlab.com/mi-org/compliance-reports` |
| `gitlab_token` | string (secreto) | Sí | Token de acceso (Personal Access Token o OAuth) para GitLab | *(inyectado por credencial)* |
| `gitlab_user` | string | Sí | Usuario Git (nombre para commits) | `ansible-bot` o usuario GitLab |
| `git_workdir` | string | Sí | Directorio temporal donde se clona el repo | `/tmp/compliance-reports-git` |
| `gitlab_repo_branch` | string | No | Rama del repositorio | `main` (default) |
| `gitlab_commit_message` | string | No | Mensaje del commit | Mensaje por defecto con clusters y fecha |

**Surveys sugeridos:**

- **do_push_gitlab**: Tipo Boolean, default `false`.
- **gitlab_repo_url**: Tipo Text, descripción “URL HTTPS del repo GitLab (ej: https://gitlab.com/org/repo)”.
- **gitlab_user**: Tipo Text, descripción “Usuario Git para commits”.
- **git_workdir**: Tipo Text, default `/tmp/compliance-reports-git`.
- **gitlab_repo_branch**: Tipo Text, default `main`.

**No** incluyas `gitlab_token` en Survey; debe venir de una **Credencial**.

---

## 3. Credenciales

| Acción | Detalle |
|--------|---------|
| **Desvincular** | Quitar la credencial de **Correo / SMTP** del Job Template si estaba asociada (envío de email). |
| **Vincular** | Añadir una credencial que proporcione el **token de GitLab** al playbook. Opciones: |
| | • **Credential Type “Machine”** con usuario y contraseña: usuario = `oauth2` o `gitlab_user`, contraseña = token. O bien usar solo Extra Vars con `gitlab_token` desde una credencial tipo “Vault” o “Custom” que inyecte el token. |
| | • **Credential Type “Custom”** con **Injector** que defina `GITLAB_TOKEN` (y opcionalmente `GITLAB_USER`) como variables de entorno. El playbook ya normaliza `GITLAB_TOKEN` y `GITLAB_USER` desde env. |
| **Confirmación** | Sí: debes **desvincular la credencial de Correo** y **vincular la nueva credencial de GitLab** (o tipo Custom que inyecte `GITLAB_TOKEN` / `GITLAB_USER`). |

---

## 4. Resumen rápido

1. Eliminar variables y Surveys de SMTP/correo.
2. Añadir variables y Surveys de GitLab (`do_push_gitlab`, `gitlab_repo_url`, `gitlab_user`, `git_workdir`, etc.).
3. Quitar credencial de Correo del Job Template; asociar credencial que aporte `gitlab_token` (o inyecte `GITLAB_TOKEN` / `GITLAB_USER`).
4. Probar el Job Template con `do_push_gitlab=true` y revisar que los reportes aparezcan en el repo en la ruta `reports/`.

---

## 5. Cambios en el rol `compliance_export_html`

El rol **sí impactaba** la ejecución cuando se dejaba la lógica de correo: el debug y la tarea de correo usaban variables (`do_send_email`, `email_to`, `email_smtp_*`, etc.) que ya no existen en el orquestador, lo que podía provocar errores de **variable indefinida** al ejecutar el playbook.

### Qué hace el rol (sin cambios, necesario para GitLab)

- Conexión al cluster (kubeconfig, ACM, PVCs).
- Búsqueda y procesamiento de PVCs de compliance (CIS/PCI).
- Descompresión de `.bzip2`, aplanado de XMLs.
- **Conversión XML → HTML** (script `render_reports.sh`).
- Generación de `summary.txt`.
- **Creación del ZIP** con los HTML y el resumen en `compliance_reports_path`.

Ese flujo es el que genera los ZIPs que el orquestador luego recoge y sube a GitLab. No se ha tocado.

### Qué se modificó en el rol

| Ubicación | Cambio |
|-----------|--------|
| `roles/compliance_export_html/tasks/main.yml` | **Eliminada** la tarea "Enviar reporte de Compliance (ZIP) por correo electrónico" (`community.general.mail`). |
| `roles/compliance_export_html/tasks/main.yml` | **Sustituido** el debug "Estado previo al correo" (que usaba `do_send_email`, `email_to`) por un debug neutro que solo muestra ruta de reportes y cluster. |
| `roles/compliance_export_html/defaults/main.yml` | Comentario actualizado: la entrega la hace el orquestador (GitLab). |

### Resumen

- **No** hay que cambiar nada en AAP por el rol: las variables que se quitan/agregan son las del orquestador (secciones 1–4 de esta guía).
- El rol ya **no** referencia correo ni variables SMTP; solo genera el ZIP. La entrega es **solo** en el orquestador vía GitLab.
