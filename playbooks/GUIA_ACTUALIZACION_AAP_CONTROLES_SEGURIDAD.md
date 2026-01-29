# GUÍA DE ACTUALIZACIÓN AAP – Roles Controles Seguridad (enforce / inform)

Checklist para actualizar Job Templates de AAP que usan los roles **controles-seguridad-enforce** y **controles-seguridad-inform** tras sustituir el envío por correo (SMTP) por subida a GitLab.

---

## 1. Variables a ELIMINAR en AAP (SMTP)

Eliminar del **Job Template** (Extra Variables, Survey o Credential/Environment) todas las variables relacionadas con correo:

| Variable | Descripción |
|----------|-------------|
| `send_mail` | Flag que activaba el envío por correo |
| `smtp_host` | Servidor SMTP (ej: smtp.gmail.com) |
| `mail_from` | Remitente del correo |
| `mail_to` | Destinatario(s) del correo |
| `email_smtp_password` | Contraseña SMTP (o variable inyectada por credencial) |

**Surveys:** Eliminar preguntas para “Enviar correo”, “Host SMTP”, “Destinatario”, “Remitente”, etc.

**Credential Type / Environment:** Si tenías un Credential Type que inyectaba `EMAIL_SMTP_PASSWORD` (u otras variables de correo), deja de usarlo o quita esas entradas del injector para estos Job Templates.

---

## 2. Variables de GitLab (mismas que el orquestador)

Los roles **controles-seguridad-enforce** y **controles-seguridad-inform** usan las **mismas variables** que el orquestador multicluster. No hace falta definir variables nuevas específicas para estos roles.

| Variable | Obligatorio si `do_push_gitlab=true` | Descripción |
|----------|--------------------------------------|-------------|
| `do_push_gitlab` | Sí (para subir reporte) | Activa la subida del reporte a GitLab (`true`/`false`) |
| `gitlab_repo_url` | Sí | URL HTTPS del repositorio GitLab |
| `gitlab_token` | Sí | Token de acceso (mejor vía credencial, no en Survey) |
| `gitlab_user` | Sí | Usuario Git para commits |
| `git_workdir` | No (hay default en rol) | Directorio temporal de clone. Default en rol: `/tmp/controles-seguridad-git` |
| `gitlab_repo_branch` | No | Rama del repositorio (default `main`) |

**Confirmación:** Las variables `do_push_gitlab`, `gitlab_repo_url`, `gitlab_token`, `gitlab_user`, `git_workdir` y `gitlab_repo_branch` **funcionan igual** aquí que en el orquestador. Si ya tienes el Job Template del orquestador configurado con esas variables (y la credencial de GitLab), puedes reutilizar la misma credencial y las mismas Extra Vars / Survey en los Job Templates de **enforce** e **inform**.

**Inyección por credencial:** El rol normaliza `GITLAB_TOKEN` y `GITLAB_USER` desde variables de entorno. Si usas un Credential Type “Custom” con injector que define `GITLAB_TOKEN` y `GITLAB_USER`, no necesitas pasar `gitlab_token` ni `gitlab_user` por Extra Vars (el rol los tomará del env).

---

## 3. Estructura en el repositorio GitLab

Los reportes de estos roles **no se mezclan** con los del orquestador:

- **Orquestador multicluster:** `reports/<cluster>/<archivo>.zip`
- **Roles enforce / inform:** `reportes_controles_seguridad/<cluster>/<archivo>.txt`

Ejemplo de rutas finales:

- `reportes_controles_seguridad/cluster-pro-1/resultado_enforce_2026-01-29T12-30-00.txt`
- `reportes_controles_seguridad/cluster-pro-1/resultado_inform_2026-01-29T12-35-00.txt`

El nombre del cluster viene de `cluster_name` (infraestructura del cluster) o, si no existe, de `inventory_hostname`.

---

## 4. Credenciales

| Acción | Detalle |
|--------|---------|
| **Desvincular** | Quitar la credencial de **Correo / SMTP** del Job Template de enforce y del Job Template de inform. |
| **Vincular** | Usar la **misma credencial de GitLab** que en el orquestador (la que aporta `gitlab_token` o inyecta `GITLAB_TOKEN` / `GITLAB_USER`). |

No hace falta una credencial distinta para estos roles; basta con la credencial de GitLab que ya uses en el orquestador.

---

## 5. Resumen rápido

1. **Eliminar** variables y Surveys de SMTP/correo (`send_mail`, `smtp_host`, `mail_from`, `mail_to`, `email_smtp_password`).
2. **Añadir** (o reutilizar) variables de GitLab: `do_push_gitlab`, `gitlab_repo_url`, `gitlab_token`, `gitlab_user`, y opcionalmente `git_workdir`, `gitlab_repo_branch`.
3. **Desvincular** credencial de Correo; **vincular** credencial de GitLab en los Job Templates de enforce e inform.
4. Probar con `do_push_gitlab=true` y comprobar que los reportes aparecen en el repo bajo `reportes_controles_seguridad/<cluster>/` con nombres `resultado_enforce_<timestamp>.txt` y `resultado_inform_<timestamp>.txt`.
