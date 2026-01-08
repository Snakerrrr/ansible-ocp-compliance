# Ejemplo de Configuración de Extra Variables en AAP

## ⚠️ IMPORTANTE: Debes poner `true` para activar cada funcionalidad

Los defaults están en `false` por seguridad. **Debes activarlos explícitamente** pasando `true`.

## Configuración Completa para "Extra Variables" en AAP

Copia y pega esto en la sección **"Extra variables"** de tu Job Template:

```yaml
---
# ============================================================
# VARIABLES DE CONTROL (DEBEN ESTAR EN true PARA ACTIVARSE)
# ============================================================
do_gitops: true          # ← true para ejecutar GitOps
do_export_html: true     # ← true para exportar reportes HTML
do_send_email: true      # ← true para enviar por correo

# ============================================================
# CONFIGURACIÓN SMTP
# ============================================================
# ⚠️ IMPORTANTE: email_smtp_password DEBE estar en Environment Variables
# ⚠️ email_smtp_username, email_from, email_to pueden estar en Survey
email_smtp_host: "smtp.gmail.com"
email_smtp_port: 587
# email_smtp_username: "bsoto@redhat.com"  # ← Mover a Survey o Environment Variable
# email_smtp_password: "xxxx"  # 🔒 CRÍTICO: Mover a Environment Variable (NUNCA aquí)
# email_to: "bsoto@redhat.com,jmunozag@redhat.com"  # ← Mover a Survey
# email_from: "bsoto@redhat.com"  # ← Mover a Survey o Environment Variable
email_subject_prefix: "Reporte AAP"
email_smtp_timeout: 90  # Opcional: aumentar para archivos grandes (default: 60)

# ============================================================
# CONFIGURACIÓN GITOPS (Si do_gitops=true)
# ============================================================
# ⚠️ IMPORTANTE: github_token DEBE estar en Source Control Credential o Environment Variable
# github_token: "ghp_xxxx"  # 🔒 CRÍTICO: Mover a Credential o Environment Variable (NUNCA aquí)
# github_user: "Snakerrrr"  # ← Mover a Survey o Environment Variable
gitops_repo_branch: "main"      # Opcional, tiene default

# ============================================================
# CONFIGURACIÓN DE ESCANEOS
# ============================================================
run_cis: true                   # Habilitar escaneo CIS (alternativa: cis_scan_enabled)
run_pci: false                  # Habilitar escaneo PCI-DSS (alternativa: pci_scan_enabled)
scan_schedule: "0 1 * * *"      # Schedule cron (default: "0 1 * * *" - 1 AM)
scan_setting_name: "periodic-daily"  # Nombre del ScanSetting (default: "periodic-daily")
scan_remediation_action: "inform"    # Acción de remediación: "inform" o "enforce"

# ============================================================
# CONFIGURACIÓN MULTI-CLUSTER (Para orchestrator)
# ============================================================
survey_target_clusters:        # Lista de clusters a procesar
  - cluster-acs
  - cluster-2
```

## Ejemplos de Configuraciones Comunes

### 1. Solo Export HTML + Email (Sin GitOps)
```yaml
do_gitops: false
do_export_html: true
do_send_email: true

email_smtp_host: "smtp.gmail.com"
email_smtp_port: 587
email_smtp_username: "bsoto@redhat.com"
email_smtp_password: "swtgocesdjeasgbx"
email_to: "bsoto@redhat.com"
email_from: "jmunozag@redhat.com"
```

### 2. Solo GitOps (Actualizar políticas)
```yaml
do_gitops: true
do_export_html: false
do_send_email: false

github_token: "TU_TOKEN_AQUI"
```

### 3. Pipeline Completo (GitOps + HTML + Email)
```yaml
do_gitops: true
do_export_html: true
do_send_email: true

github_token: "TU_TOKEN_AQUI"
email_smtp_host: "smtp.gmail.com"
email_smtp_port: 587
email_smtp_username: "bsoto@redhat.com"
email_smtp_password: "swtgocesdjeasgbx"
email_to: "bsoto@redhat.com"
email_from: "jmunozag@redhat.com"
```

## Tabla de Referencia Rápida

| Variable | Valor para Activar | Valor para Desactivar | Default |
|---------|---------------------|----------------------|---------|
| `do_gitops` | `true` | `false` | `false` |
| `do_export_html` | `true` | `false` | `false` |
| `do_send_email` | `true` | `false` | `false` |

## ⚠️ Reglas Importantes

1. **`do_gitops=true`** requiere `github_token` (debe estar en Credential o Environment Variable)
2. **`do_send_email=true`** requiere `do_export_html=true` (no tiene sentido enviar correo sin reportes)
3. **`do_send_email=true`** requiere todas las variables SMTP configuradas
4. **🔒 Credenciales sensibles** (`email_smtp_password`, `github_token`) **NUNCA** deben estar en Extra Variables en texto plano

## 📚 Guía de Migración de Credenciales

Si tienes credenciales en Extra Variables, consulta la guía:
**[MIGRACION-CREDENCIALES-EXTRA-VARS.md](MIGRACION-CREDENCIALES-EXTRA-VARS.md)**

Esta guía explica cómo mover credenciales de forma segura a Environment Variables y Survey.

## Cómo Funciona la Lógica

```yaml
# En el playbook:
when: do_gitops | bool  # ← Se ejecuta SOLO si do_gitops=true
```

Esto significa:
- ✅ `do_gitops: true` → **Se ejecuta GitOps**
- ❌ `do_gitops: false` → **NO se ejecuta GitOps**
- ❌ `do_gitops` no definido → **NO se ejecuta GitOps** (usa default=false)

## Recomendación para AAP

**Usa una Survey** en AAP para que los usuarios puedan seleccionar qué ejecutar:

1. Ve a la pestaña **"Survey"** en tu Job Template
2. Crea preguntas tipo checkbox o boolean para:
   - `do_gitops`
   - `do_export_html`
   - `do_send_email`
3. Así los usuarios pueden activar/desactivar desde la interfaz sin editar YAML

## Ejemplo de Survey en AAP

```
Pregunta 1:
  Variable: do_gitops
  Tipo: Boolean
  Default: false
  Pregunta: "¿Ejecutar GitOps (actualizar políticas)?"

Pregunta 2:
  Variable: do_export_html
  Tipo: Boolean
  Default: true
  Pregunta: "¿Exportar reportes HTML?"

Pregunta 3:
  Variable: do_send_email
  Tipo: Boolean
  Default: true
  Pregunta: "¿Enviar reportes por correo?"
```

---

**Resumen**: Siempre pon `true` para activar. Los defaults en `false` son por seguridad.

