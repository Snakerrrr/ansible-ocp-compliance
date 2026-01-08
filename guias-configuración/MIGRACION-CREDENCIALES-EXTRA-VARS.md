# Guía de Migración: Mover Credenciales de Extra Vars a Configuración Segura

## 📋 Resumen

Esta guía te ayudará a mover credenciales que están actualmente en **Extra Variables** del Job Template a una configuración más segura usando **Environment Variables** y **Survey**.

## 🔒 Clasificación de Credenciales

### ❌ CRÍTICAS - NUNCA en Survey o Extra Vars (texto plano)

Estas credenciales **NUNCA** deben estar en texto plano en Survey o Extra Variables porque aparecen en los logs:

- `email_smtp_password` - Contraseña SMTP
- `github_token` - Token de GitHub (si lo tienes en extra_vars)

**Solución**: Environment Variables o Credentials

### ✅ CONFIGURACIÓN - Pueden estar en Survey

Estas variables pueden estar en Survey porque no son secretos sensibles:

- `email_smtp_username` - Usuario SMTP (puede estar en Survey o Environment Variable)
- `email_from` - Remitente (puede estar en Survey)
- `email_to` - Destinatarios (puede estar en Survey)
- `github_user` - Usuario de GitHub (puede estar en Survey o Extra Vars)

---

## 🚀 Pasos de Migración

### Paso 1: Configurar Environment Variables (Credenciales Sensibles)

1. **Ir al Job Template en AAP**
   - Navega a: Resources → Templates → Tu Job Template
   - Click en la pestaña **"Details"** o **"Detalles"**

2. **Agregar Environment Variables**
   - Busca la sección **"Environment Variables"** o **"Variables de Entorno"**
   - Agrega las siguientes variables (formato KEY=VALUE, una por línea):

```yaml
# --- CREDENCIALES SMTP (Sensibles) ---
EMAIL_SMTP_PASSWORD: nftvimyoptzvbozd

# --- TOKEN DE GITHUB (Si lo tienes en extra_vars) ---
# GITHUB_TOKEN: ghp_xxxxxxxxxxxx
```

**⚠️ IMPORTANTE**: 
- Estas variables NO aparecen en los logs
- Son la forma más segura de manejar contraseñas
- Si usas Gmail, `EMAIL_SMTP_PASSWORD` debe ser una **Contraseña de Aplicación**

### Paso 2: Configurar Survey (Variables de Configuración)

1. **Ir a la pestaña Survey del Job Template**
   - En tu Job Template, click en la pestaña **"Survey"**

2. **Crear preguntas del Survey**

#### Pregunta 1: Usuario SMTP

- **Question Name**: `email_smtp_username`
- **Question Description**: `Usuario SMTP para envío de correos`
- **Answer Variable Name**: `email_smtp_username`
- **Field Type**: `Text`
- **Required**: ✅ Yes
- **Default Answer**: `bsoto@redhat.com`

#### Pregunta 2: Remitente

- **Question Name**: `email_from`
- **Question Description**: `Dirección de correo remitente`
- **Answer Variable Name**: `email_from`
- **Field Type**: `Text`
- **Required**: ✅ Yes
- **Default Answer**: `bsoto@redhat.com`

#### Pregunta 3: Destinatarios

- **Question Name**: `email_to`
- **Question Description**: `Lista de destinatarios (separados por comas o uno por línea)`
- **Answer Variable Name**: `email_to`
- **Field Type**: `Textarea`
- **Required**: ✅ Yes (si `do_send_email=true`)
- **Default Answer**: 
  ```
  basti.soto.sanchez@gmail.com
  bsoto@redhat.com
  jmunozag@redhat.com
  ```

#### Pregunta 4: Usuario GitHub

- **Question Name**: `github_user`
- **Question Description**: `Usuario de GitHub para GitOps`
- **Answer Variable Name**: `github_user`
- **Field Type**: `Text`
- **Required**: ✅ Yes (si `do_gitops=true`)
- **Default Answer**: `Snakerrrr`

### Paso 3: Actualizar Extra Variables

**Eliminar** las siguientes líneas de Extra Variables:

```yaml
# ❌ ELIMINAR ESTAS LÍNEAS:
email_smtp_username: bsoto@redhat.com
email_from: bsoto@redhat.com
email_smtp_password: nftvimyoptzvbozd  # ← CRÍTICO: Eliminar
email_to:
  - basti.soto.sanchez@gmail.com
  - bsoto@redhat.com
  - jmunozag@redhat.com
github_user: Snakerrrr
```

**Mantener** en Extra Variables solo las variables de control y configuración no sensible:

```yaml
# ✅ MANTENER EN EXTRA VARIABLES:
do_gitops: false
do_export_html: false
do_send_email: false

# Configuración SMTP (sin contraseña)
email_smtp_host: "smtp.gmail.com"
email_smtp_port: 587
email_subject_prefix: "Reporte de Compliance"

# Configuración GitOps (sin token)
gitops_repo_branch: "main"
```

### Paso 4: El Playbook ya está Actualizado ✅

**¡Buenas noticias!** El playbook ya está modificado para leer automáticamente desde Environment Variables. No necesitas hacer cambios adicionales en el código.

**Cómo funciona (El "Puente" automático)**:
1. En AAP, las Environment Variables se inyectan como variables de entorno del SO (`os.environ`)
2. El playbook tiene una tarea de normalización al inicio que hace el "puente" usando `lookup('env', 'VARIABLE')`
3. Si la Environment Variable existe (ej: `EMAIL_SMTP_PASSWORD`), la lee y la asigna a la variable de Ansible (`email_smtp_password`)
4. Si no existe, usa la variable de Ansible directamente (de Survey o Extra Vars)
5. Esto permite usar Environment Variables sin necesidad de mapearlas manualmente en Extra Vars

**Código del "Puente" en el playbook**:
```yaml
- name: Normalizar credenciales desde Environment Variables
  ansible.builtin.set_fact:
    email_smtp_password: "{{ lookup('env', 'EMAIL_SMTP_PASSWORD') | default(email_smtp_password | default('')) }}"
    github_token: "{{ lookup('env', 'GITHUB_TOKEN') | default(github_token | default('')) }}"
    # ... otras variables
```

**Por qué es necesario**: Ansible no convierte automáticamente las Environment Variables del SO en variables de Ansible. El `lookup('env', ...)` hace el "puente" explícito.

**Variables soportadas automáticamente desde Environment Variables**:
- `EMAIL_SMTP_PASSWORD` → `email_smtp_password`
- `EMAIL_SMTP_USERNAME` → `email_smtp_username`
- `EMAIL_FROM` → `email_from`
- `EMAIL_TO` → `email_to`
- `GITHUB_TOKEN` → `github_token`
- `GITHUB_USER` → `github_user`

**Ejemplo**: Si configuras `EMAIL_SMTP_PASSWORD` en Environment Variables, el playbook la leerá automáticamente sin necesidad de ponerla en Extra Vars o Survey.

**Alternativa (Opcional)**: Si prefieres mapear explícitamente en Extra Variables, puedes hacerlo:

```yaml
# Opción: Mapeo explícito en Extra Variables (NO es necesario, pero es válido)
email_smtp_password: "{{ lookup('env', 'EMAIL_SMTP_PASSWORD') }}"
github_token: "{{ lookup('env', 'GITHUB_TOKEN') }}"
```

**Nota**: Esta opción es redundante porque el playbook ya hace esto automáticamente, pero puede ser útil si quieres tener control explícito sobre el mapeo.

---

## 📊 Comparación de Opciones

### Opción A: Environment Variables + Survey (Recomendado)

| Variable | Ubicación | Razón |
|----------|-----------|-------|
| `email_smtp_password` | Environment Variables | 🔒 Sensible, no aparece en logs |
| `email_smtp_username` | Survey | ✅ Configuración, puede cambiar por ejecución |
| `email_from` | Survey | ✅ Configuración, puede cambiar por ejecución |
| `email_to` | Survey | ✅ Configuración, puede cambiar por ejecución |
| `github_user` | Survey | ✅ Configuración, puede cambiar por ejecución |

**Ventajas**:
- ✅ Contraseñas seguras (no en logs)
- ✅ Flexibilidad para cambiar destinatarios por ejecución
- ✅ Mejor experiencia de usuario (Survey es más amigable)

### Opción B: Todo en Environment Variables

| Variable | Ubicación | Razón |
|----------|-----------|-------|
| `email_smtp_password` | Environment Variables | 🔒 Sensible |
| `email_smtp_username` | Environment Variables | ✅ Fijo, no cambia |
| `email_from` | Environment Variables | ✅ Fijo, no cambia |
| `email_to` | Environment Variables | ⚠️ Fijo, menos flexible |
| `github_user` | Environment Variables | ✅ Fijo, no cambia |

**Ventajas**:
- ✅ Todo centralizado
- ✅ No requiere Survey
- ⚠️ Menos flexible (no puedes cambiar destinatarios fácilmente)

**Cuándo usar**: Si los valores son fijos y no necesitas cambiarlos por ejecución.

---

## 🔐 Configuración Recomendada (Opción A)

### Environment Variables del Job Template

```yaml
# Credenciales sensibles (NUNCA en logs)
EMAIL_SMTP_PASSWORD: nftvimyoptzvbozd
GITHUB_TOKEN: ghp_xxxxxxxxxxxx  # Si lo tienes en extra_vars
```

### Survey del Job Template

1. **email_smtp_username** (Text, Required, Default: `bsoto@redhat.com`)
2. **email_from** (Text, Required, Default: `bsoto@redhat.com`)
3. **email_to** (Textarea, Required, Default: lista de destinatarios)
4. **github_user** (Text, Required si do_gitops=true, Default: `Snakerrrr`)

### Extra Variables del Job Template

```yaml
# Solo variables de control y configuración no sensible
do_gitops: false
do_export_html: false
do_send_email: false

email_smtp_host: "smtp.gmail.com"
email_smtp_port: 587
email_subject_prefix: "Reporte de Compliance"
gitops_repo_branch: "main"
```

---

## ✅ Checklist de Migración

- [ ] Crear Environment Variables para `EMAIL_SMTP_PASSWORD` en el Job Template
- [ ] Crear Environment Variables para `GITHUB_TOKEN` (si aplica) en el Job Template
- [ ] Crear Survey con preguntas para `email_smtp_username`, `email_from`, `email_to`, `github_user`
- [ ] Eliminar credenciales sensibles de Extra Variables (`email_smtp_password`, `github_token`)
- [ ] **Verificar que el playbook está actualizado** (debe tener la tarea "Normalizar credenciales desde Environment Variables")
- [ ] Probar ejecución del Job Template
- [ ] Verificar que los correos se envían correctamente
- [ ] Verificar que GitOps funciona (si aplica)
- [ ] Verificar en los logs que `email_smtp_password` NO aparece en texto plano

---

## 🧪 Prueba de Verificación

Después de la migración, ejecuta el Job Template y verifica:

1. **En los logs del Job**:
   - ✅ NO debe aparecer `email_smtp_password` en texto plano
   - ✅ NO debe aparecer `github_token` en texto plano (si lo moviste)
   - ✅ Debe aparecer `email_smtp_username` (es normal, no es sensible)
   - ✅ Debe aparecer `email_to` (es normal, no es sensible)

2. **Funcionalidad**:
   - ✅ El correo se envía correctamente
   - ✅ Los destinatarios son correctos
   - ✅ GitOps funciona (si aplica)

---

## 📝 Notas Importantes

1. **Gmail Contraseña de Aplicación**: Si usas Gmail, `EMAIL_SMTP_PASSWORD` debe ser una **Contraseña de Aplicación**, no tu contraseña normal. Ver: https://myaccount.google.com/apppasswords

2. **Múltiples Destinatarios**: El playbook soporta múltiples destinatarios separados por comas o saltos de línea. El Survey puede aceptar ambos formatos.

3. **Rotación de Credenciales**: Con Environment Variables, puedes rotar contraseñas sin modificar el código, solo actualizando la variable en el Job Template.

4. **Auditoría**: Las Environment Variables no aparecen en los logs, lo que mejora la seguridad y cumple con políticas de auditoría.

---

## 🆘 Troubleshooting

### Error: "Faltan variables de Correo"

**Causa**: Las variables no se están pasando correctamente desde el Survey o Environment Variables.

**Solución**:
1. Verificar que el Survey esté activado (Survey Enabled = ✅)
2. Verificar que las preguntas del Survey tengan los nombres correctos
3. Verificar que las Environment Variables estén configuradas correctamente
4. **Verificar que el playbook tenga la tarea de normalización**: Debe aparecer "Normalizar credenciales desde Environment Variables" al inicio del playbook

### Error: "email_smtp_password is not defined" o "email_smtp_password no está definida"

**Causa**: La variable `EMAIL_SMTP_PASSWORD` no está configurada en Environment Variables del Job Template, y tampoco está en Survey o Extra Vars.

**Solución**:
1. **Verificar que la Environment Variable esté configurada**:
   - Ir al Job Template → pestaña "Details" o "Detalles"
   - Buscar sección "Environment Variables" o "Variables de Entorno"
   - Verificar que existe `EMAIL_SMTP_PASSWORD` con el valor correcto
   - **El nombre debe ser exactamente `EMAIL_SMTP_PASSWORD` (mayúsculas)**

2. **Verificar en los logs**:
   - Buscar la tarea "Normalizar credenciales desde Environment Variables"
   - Si la Environment Variable está configurada, el playbook la leerá automáticamente
   - Si no está configurada, el playbook intentará usar la variable de Survey o Extra Vars

3. **Si la Environment Variable está configurada pero sigue fallando**:
   - Verificar que el Job Template tenga acceso a las Environment Variables
   - Verificar que no haya espacios extra en el nombre de la variable
   - Verificar que el playbook tenga la tarea de normalización (debe estar en la sección 2)
   - Probar reiniciar el Job Template o AAP

4. **Solución temporal (NO recomendado para producción)**:
   - Puedes poner `email_smtp_password` en Extra Vars temporalmente para debugging:
     ```yaml
     email_smtp_password: "nftvimyoptzvbozd"
     ```
   - **⚠️ Esto aparecerá en los logs, solo para debugging**

### Error: "Authentication failed" al enviar correo

**Causa**: La contraseña SMTP es incorrecta o está expirada.

**Solución**:
1. Verificar que `EMAIL_SMTP_PASSWORD` esté configurada en Environment Variables
2. Si usas Gmail, generar una nueva Contraseña de Aplicación
3. Verificar que el usuario SMTP sea correcto

### Los destinatarios no reciben el correo

**Causa**: El formato de `email_to` puede estar incorrecto.

**Solución**:
1. Verificar que los destinatarios estén separados por comas o saltos de línea
2. Verificar que no haya espacios extra
3. Probar con un solo destinatario primero

---

**Última actualización**: 2024

