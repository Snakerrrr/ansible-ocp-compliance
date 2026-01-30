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

---

## 6. AAP: Survey (clusters), credenciales HUB y Git

### Survey y variable `survey_target_clusters`

- **Orquestador** (`orchestrator_aap_multicluster.yml`): usa **`survey_target_clusters`** para saber en qué clusters ejecutar (GitOps, export HTML, push GitLab). La Survey que tienes con “clusters a ejecutar” y esa variable es la correcta; **manténla**.
- **Playbooks Enforce / Inform** (`enforce.yaml`, `inform.yaml`): los roles reciben **`target_clusters_list`** (lista) y **iteran ellos mismos** sobre cada cluster. Los playbooks construyen esa lista desde **`survey_target_clusters`** (misma variable que el orquestador). Así puedes usar **la misma pregunta de Survey** en los Job Templates de Enforce e Inform.

---

## 7. Qué modificar o agregar en AAP para que Enforce/Inform funcionen

Checklist para que los Job Templates que ejecutan **enforce.yaml** o **inform.yaml** funcionen con la lista de clusters y la conexión Hub-to-Spoke.

### 1. Survey (recomendado)

Puedes usar **Multiple choice (multi-select)** para que el usuario elija en qué clusters ejecutar.

| Opción | Cómo configurarlo |
|--------|--------------------|
| **Multiple choice (multi-select)** | En la Survey del Job Template, crea una pregunta con **variable:** `survey_target_clusters`. **Tipo:** "Multiple choice (multi-select)". En **Answer type:** elige "Select multiple". En **Choices** escribe cada cluster como una línea (ej.: `cluster-a`, `cluster-b`, `cluster-c`). AAP enviará la selección como lista; los playbooks la aceptan tal cual. |
| **Text / Textarea** | **Variable:** `survey_target_clusters`. **Tipo:** Text o Textarea. Formato: un cluster por línea, o separados por comas. Los playbooks convierten texto (saltos de línea o comas) en lista. |

| Campo | Valor |
|--------|--------|
| **Variable** | `survey_target_clusters` (igual que en el orquestador). |
| **Descripción sugerida** | “Selecciona los clusters en los que ejecutar (o escribe uno por línea / separados por comas). Debe coincidir con el nombre del namespace del cluster en el Hub ACM.” |
| **Obligatoria** | Opcional: si no se selecciona nada, el job hace 0 iteraciones (no falla). |

**Recomendación:** Usar **Multiple choice (multi-select)** con la lista de clusters en Choices da mejor experiencia: el usuario solo marca los clusters deseados y AAP envía la lista correcta.

### 2. Extra Variables (alternativa a Survey)

Si no usas Survey, pasa los clusters por **Extra Variables** del Job Template:

- **Opción A:** `survey_target_clusters` como texto, un cluster por línea. Ejemplo en YAML:  
  `survey_target_clusters: "cluster-a\ncluster-b\ncluster-c"`
- **Opción B:** Si tu AAP permite pasar listas en Extra Variables, puedes definir:  
  `target_clusters_list: ["cluster-a", "cluster-b"]`  
  En ese caso, como los playbooks definen `target_clusters_list` desde `survey_target_clusters`, si pasas `target_clusters_list` por Extra Variables puede tener prioridad (depende de AAP); si no, usa la Opción A.

### 3. Credenciales

| Credencial | Dónde | Acción |
|------------|--------|--------|
| **HUB ACM** (OpenShift/Kubernetes o Kubeconfig) | Job Template de Enforce y Job Template de Inform | **Añadir / vincular.** El playbook necesita conectarse al Hub para ejecutar `oc get secret admin-kubeconfig -n <cluster>`. Sin esta credencial, la extracción del kubeconfig del spoke fallará. |
| **Git (Source Control)** | Proyecto del Job Template | Mantener si el Proyecto obtiene el código desde un repo Git. No es necesaria para la lógica de clusters ni para GitOps. |

### 4. Playbook e inventario

| Campo | Valor |
|--------|--------|
| **Playbook** | `enforce.yaml` o `inform.yaml` según el Job Template. |
| **Inventario** | Puede ser un inventario con un único host (p. ej. `localhost`) o el que use el orquestador. Los playbooks están configurados con `hosts: localhost` para que todo se ejecute en el nodo que tiene acceso al Hub. |

### 5. Resumen rápido (Enforce/Inform en AAP)

1. **Survey o Extra Variables:** variable `survey_target_clusters`. Puedes usar **Multiple choice (multi-select)** en la Survey (recomendado) o Text/Textarea (un cluster por línea o separados por comas). También puedes pasar `target_clusters_list` como lista por Extra Variables.
2. **Credencial HUB ACM:** vinculada a los Job Templates de Enforce e Inform.
3. **Credencial Git:** en el Proyecto, si el código se clona desde Git.
4. **Playbook:** `enforce.yaml` o `inform.yaml`; `hosts: localhost` ya está en el playbook.

Con esto, al lanzar el job se procesarán todos los clusters que indiques en `survey_target_clusters` (o en `target_clusters_list`) en una sola ejecución.
