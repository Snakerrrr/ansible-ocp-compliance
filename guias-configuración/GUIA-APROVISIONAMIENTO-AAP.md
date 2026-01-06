# Guía Completa de Aprovisionamiento en Ansible Automation Platform (AAP)

## 📋 Tabla de Contenidos

1. [Pre-requisitos Técnicos](#pre-requisitos-técnicos)
2. [Arquitectura y Flujo](#arquitectura-y-flujo)
3. [Configuración de AAP](#configuración-de-aap)
4. [Variables Requeridas y Opcionales](#variables-requeridas-y-opcionales)
5. [Configuración de Credenciales](#configuración-de-credenciales)
6. [Configuración de Job Template](#configuración-de-job-template)
7. [Consideraciones de Seguridad](#consideraciones-de-seguridad)
8. [Troubleshooting](#troubleshooting)
9. [Ejemplos de Configuración](#ejemplos-de-configuración)

---

## Pre-requisitos Técnicos

### 1. Infraestructura OpenShift

- **OpenShift Hub Cluster** (ACM Hub) con:
  - Advanced Cluster Management (ACM) instalado y configurado
  - Compliance Operator instalado en el Hub
  - Managed Clusters registrados y en estado `Ready`
  - Acceso desde AAP al Hub Cluster (kubeconfig o Bearer Token)

- **Managed Clusters** con:
  - Compliance Operator instalado en cada cluster
  - Namespace `openshift-compliance` creado
  - PVCs de compliance generados (resultado de escaneos previos)

### 2. Ansible Automation Platform

- **AAP 2.x o superior** instalado y operativo
- **Execution Environment** con:
  - Python 3.9+
  - Módulos de Ansible requeridos:
    - `community.general` (para `mail` y `archive`)
    - `kubernetes.core` (para operaciones con Kubernetes)
  - Herramientas CLI:
    - `oc` (OpenShift CLI)
    - `git`
    - `tar`, `bzip2` (para descompresión)
    - `zip` (para compresión)

### 3. Repositorio GitOps (Opcional - Solo si `do_gitops=true`)

- Repositorio Git accesible desde AAP
- Branch configurado para GitOps
- Token de acceso con permisos de escritura (push)

### 4. Servidor SMTP (Opcional - Solo si `do_send_email=true`)

- Servidor SMTP accesible desde AAP
- Credenciales válidas
- Puerto habilitado (generalmente 587 para STARTTLS)

---

## Arquitectura y Flujo

### Flujo de Ejecución

```
┌─────────────────────────────────────────────────────────────┐
│                    AAP Job Template                          │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  orchestrator_aap_multicluster.yml                   │   │
│  │                                                        │   │
│  │  1. Validación de Variables                          │   │
│  │  2. Normalización de Clusters                         │   │
│  │  3. Fase GitOps (si do_gitops=true)                  │   │
│  │     └─> gitops_policy_update                          │   │
│  │         └─> toggle_policies                          │   │
│  │  4. Fase Extracción (por cada cluster)               │   │
│  │     └─> compliance_export_html                       │   │
│  │         └─> process_pvc (CIS y PCI)                 │   │
│  │  5. Envío Consolidado de Correos                      │   │
│  │     └─> Un solo correo con todos los ZIPs            │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Componentes Principales

1. **Playbook Orquestador**: `orchestrator_aap_multicluster.yml`
   - Punto de entrada único
   - Gestiona el flujo multi-cluster
   - Valida variables y configuración

2. **Rol GitOps**: `gitops_policy_update`
   - Clona repositorio GitOps
   - Actualiza políticas de compliance
   - Hace commit y push

3. **Rol Export HTML**: `compliance_export_html`
   - Extrae reportes desde PVCs
   - Genera reportes HTML
   - Comprime en ZIP

4. **Rol Toggle Policies**: `toggle_policies`
   - Genera `policy-generator-config.yaml`
   - Genera `scan-setting.yaml`
   - Renderiza templates Jinja2

---

## Configuración de AAP

### 1. Execution Environment

#### Crear Execution Environment Personalizado

**Requisitos mínimos del EE:**

```dockerfile
FROM quay.io/ansible/ansible-runner:latest

# Instalar herramientas CLI
RUN dnf install -y git tar bzip2 zip && \
    dnf clean all

# Instalar módulos de Ansible requeridos
RUN ansible-galaxy collection install community.general kubernetes.core

# Instalar OpenShift CLI (oc)
RUN curl -L https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz | \
    tar -xz -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/oc
```

**Alternativa: Usar EE Base de Red Hat**

Si tienes acceso a Red Hat Automation Hub, puedes usar:
- `ee-supported-rhel8` (incluye `community.general` y `kubernetes.core`)

Luego agregar `oc` manualmente o crear un EE personalizado basado en este.

### 2. Project (Proyecto)

1. **Navegar a**: Resources → Projects
2. **Crear nuevo proyecto**:
   - **Name**: `compliance-automation`
   - **Organization**: Seleccionar organización
   - **Source Control Type**: Git
   - **Source Control URL**: URL del repositorio con los playbooks
   - **Source Control Branch/Tag/Commit**: `main` (o la rama correspondiente)
   - **Source Control Credential**: Credencial de Source Control (ver sección de Credenciales)
   - **Options**:
     - ✅ Clean
     - ✅ Delete
     - ✅ Update Revision on Launch

### 3. Inventory (Inventario)

1. **Navegar a**: Resources → Inventories
2. **Crear nuevo inventario**:
   - **Name**: `compliance-localhost`
   - **Organization**: Seleccionar organización
3. **Agregar host**:
   - **Name**: `localhost`
   - **Variables** (opcional):
     ```yaml
     ansible_connection: local
     ansible_python_interpreter: auto_silent
     ```

**Nota**: El playbook se ejecuta en `localhost`, por lo que el inventario es mínimo.

### 4. Credentials (Credenciales)

Ver sección detallada: [Configuración de Credenciales](#configuración-de-credenciales)

---

## Variables Requeridas y Opcionales

### Flags de Control (Requeridos)

| Variable | Tipo | Default | Descripción |
|----------|------|---------|-------------|
| `do_gitops` | boolean | `false` | Activa la fase GitOps (actualización de políticas) |
| `do_export_html` | boolean | `false` | Activa la extracción de reportes HTML |
| `do_send_email` | boolean | `false` | Activa el envío de correos consolidados |

**⚠️ IMPORTANTE**: Al menos `do_gitops` o `do_export_html` debe estar en `true`.

### Variables de Clusters (Requeridas si `do_export_html=true`)

| Variable | Tipo | Descripción | Ejemplo |
|----------|------|-------------|---------|
| `survey_target_clusters` | list/string | Lista de nombres de clusters a procesar | `["cluster-acs", "cluster-2"]` o `"cluster-acs\ncluster-2"` |

### Variables de GitOps (Requeridas si `do_gitops=true`)

| Variable | Tipo | Descripción | Ejemplo |
|----------|------|-------------|---------|
| `github_user` | string | Usuario de GitHub | `mi-usuario` |
| `github_token` | string | Token de GitHub con permisos de escritura | `ghp_xxxxxxxxxxxx` |
| `gitops_repo_branch` | string | Branch del repositorio GitOps | `main` |

**🔒 SEGURIDAD**: `github_token` debe configurarse como **Credential de Source Control** o **Environment Variable** (nunca en Survey o Extra Vars en texto plano).

### Variables de GitOps (Opcionales)

| Variable | Tipo | Default | Descripción |
|----------|------|---------|-------------|
| `run_cis` | boolean | `true` | Habilitar escaneo CIS |
| `run_pci` | boolean | `false` | Habilitar escaneo PCI-DSS |
| `scan_remediation_action` | string | `inform` | Acción de remediación (`inform`, `enforce`) |
| `install_operator_remediation_action` | string | `enforce` | Acción para instalación del operador |
| `placement_label_key` | string | `compliance` | Key del label de placement |
| `placement_label_value` | string | `enabled` | Valor del label de placement |
| `placement_use_matchlabels` | boolean | `true` | Usar matchLabels en lugar de matchExpressions |
| `scan_schedule` | string | `0 2 * * *` | Cron schedule para escaneos (formato cron) |
| `scan_setting_name` | string | `periodic-daily` | Nombre del ScanSetting |

### Variables de Correo (Requeridas si `do_send_email=true`)

| Variable | Tipo | Descripción | Ejemplo |
|----------|------|-------------|---------|
| `email_smtp_host` | string | Servidor SMTP | `smtp.gmail.com` |
| `email_smtp_port` | integer | Puerto SMTP | `587` |
| `email_smtp_username` | string | Usuario SMTP | `usuario@empresa.com` |
| `email_smtp_password` | string | Contraseña SMTP | `contraseña` |
| `email_to` | string/list | Destinatario(s) | `"admin@empresa.com"` o `"admin@empresa.com,auditor@empresa.com"` |
| `email_from` | string | Remitente (opcional) | `compliance@empresa.com` |
| `email_subject_prefix` | string | Prefijo del asunto | `Reporte de compliance multicluster` |
| `email_smtp_timeout` | integer | Timeout en segundos para operaciones SMTP (opcional) | `60` (default: 60) |

**🔒 SEGURIDAD**: `email_smtp_password` debe configurarse como **Environment Variable** o **Machine Credential** (nunca en Survey o Extra Vars en texto plano).

**ℹ️ NOTA**: Si experimentas timeouts al enviar correos con archivos grandes, aumenta `email_smtp_timeout` a 90 o 120 segundos.

### Variables de OpenShift (Opcionales)

| Variable | Tipo | Default | Descripción |
|----------|------|---------|-------------|
| `compliance_namespace` | string | `openshift-compliance` | Namespace donde están los PVCs |
| `target_cluster_context` | string | `inventory_hostname` | Contexto del cluster (se establece automáticamente) |
| `managed_cluster_name` | string | `target_cluster_context` | Nombre del managed cluster (se establece automáticamente) |

---

## Configuración de Credenciales

### 1. Credencial de Source Control (GitHub)

**Para**: `github_token` y acceso al repositorio GitOps

1. **Navegar a**: Resources → Credentials
2. **Crear nueva credencial**:
   - **Name**: `github-gitops-token`
   - **Credential Type**: `Source Control`
   - **Organization**: Seleccionar organización
   - **Configuration**:
     - **Username**: `{{ github_user }}` (o el usuario real)
     - **Password/Token**: Token de GitHub (con permisos `repo`)
     - **SCM Type**: `Git`
   - **Options**:
     - ✅ Update on Launch

**Generar Token de GitHub:**
1. Ir a: https://github.com/settings/tokens
2. Generate new token (classic)
3. Seleccionar scope: `repo` (acceso completo a repositorios)
4. Copiar el token generado

### 2. Credencial de OpenShift/Kubernetes

**Para**: Acceso al Hub Cluster desde AAP

1. **Navegar a**: Resources → Credentials
2. **Crear nueva credencial**:
   - **Name**: `openshift-hub-cluster`
   - **Credential Type**: `OpenShift or Kubernetes API Bearer Token`
   - **Organization**: Seleccionar organización
   - **Configuration**:
     - **OpenShift/ Kubernetes API Endpoint**: URL del API del Hub
     - **Token**: Bearer Token del Hub Cluster
   - **Options**:
     - ✅ Verify SSL (si usas certificados válidos)

**Obtener Bearer Token del Hub:**
```bash
oc whoami -t
```

### 3. Machine Credential (Opcional - Para SMTP)

**Para**: `email_smtp_password` (alternativa a Environment Variables)

1. **Navegar a**: Resources → Credentials
2. **Crear nueva credencial**:
   - **Name**: `smtp-password`
   - **Credential Type**: `Machine`
   - **Organization**: Seleccionar organización
   - **Configuration**:
     - **Username**: `{{ email_smtp_username }}`
     - **Password**: Contraseña SMTP
   - **Options**:
     - ✅ Prompt on Launch (para mayor seguridad)

**Nota**: Esta credencial no se usa directamente, pero puedes referenciarla en Extra Vars usando `lookup('env', 'SMTP_PASSWORD')` si la configuras como Environment Variable.

### 4. Environment Variables (Recomendado para Secretos)

**Para**: `github_token` y `email_smtp_password`

1. **En Job Template** → **Environment Variables**:
   ```yaml
   GITHUB_TOKEN: "ghp_xxxxxxxxxxxx"
   EMAIL_SMTP_PASSWORD: "contraseña_smtp"
   ```

2. **En el Survey o Extra Vars**, referenciar:
   ```yaml
   github_token: "{{ lookup('env', 'GITHUB_TOKEN') }}"
   email_smtp_password: "{{ lookup('env', 'EMAIL_SMTP_PASSWORD') }}"
   ```

**⚠️ IMPORTANTE**: Las Environment Variables no se muestran en los logs, lo que las hace más seguras que Extra Vars.

---

## Configuración de Job Template

### 1. Crear Job Template

1. **Navegar a**: Resources → Templates
2. **Crear nuevo Job Template**:
   - **Name**: `Compliance Multi-Cluster Automation`
   - **Job Type**: `Run`
   - **Inventory**: `compliance-localhost` (creado anteriormente)
   - **Project**: `compliance-automation` (creado anteriormente)
   - **Playbook**: `playbooks/orchestrator_aap_multicluster.yml`
   - **Execution Environment**: Seleccionar el EE personalizado
   - **Credentials**: 
     - `openshift-hub-cluster` (si usas Bearer Token)
     - `github-gitops-token` (si usas Source Control Credential)
   - **Forks**: `1` (el playbook se ejecuta en localhost)
   - **Verbosity**: `1` (Normal) o `2` (More Verbose) para debugging
   - **Options**:
     - ✅ Enable Privilege Escalation (si es necesario)
     - ✅ Enable Fact Gathering
     - ✅ Enable Concurrent Jobs (si quieres ejecutar múltiples jobs)

### 2. Configurar Extra Variables

**En Job Template** → **Variables** → **Extra Variables**:

```yaml
# Flags de Control
do_gitops: true
do_export_html: true
do_send_email: true

# Variables de Clusters (se pueden pasar vía Survey)
# survey_target_clusters: ["cluster-acs", "cluster-2"]

# Variables de GitOps (si do_gitops=true)
github_user: "mi-usuario-github"
gitops_repo_branch: "main"
# github_token se pasa vía Environment Variable o Credential

# Variables de Correo (si do_send_email=true)
email_smtp_host: "smtp.gmail.com"
email_smtp_port: 587
email_smtp_username: "compliance@empresa.com"
email_from: "compliance@empresa.com"
email_subject_prefix: "Reporte de compliance multicluster"
# email_smtp_password se pasa vía Environment Variable
# email_to se pasa vía Survey

# Variables Opcionales de GitOps
run_cis: true
run_pci: false
scan_remediation_action: "inform"
scan_schedule: "0 2 * * *"
placement_label_key: "compliance"
placement_label_value: "enabled"
```

### 3. Configurar Environment Variables

**En Job Template** → **Environment Variables**:

```yaml
GITHUB_TOKEN: "ghp_xxxxxxxxxxxx"
EMAIL_SMTP_PASSWORD: "contraseña_smtp"
```

**⚠️ IMPORTANTE**: Estas variables son sensibles y no se muestran en logs.

### 4. Configurar Survey (Opcional pero Recomendado)

**En Job Template** → **Survey** → **Add**:

#### Survey 1: Clusters a Procesar

- **Question Name**: `survey_target_clusters`
- **Question Description**: `Lista de clusters a procesar (uno por línea o separados por comas)`
- **Answer Variable Name**: `survey_target_clusters`
- **Field Type**: `Textarea`
- **Required**: ✅ Yes
- **Default Answer**: 
  ```
  cluster-acs
  cluster-2
  ```

#### Survey 2: Flags de Control

- **Question Name**: `do_gitops`
- **Question Description**: `¿Ejecutar fase GitOps? (actualizar políticas)`
- **Answer Variable Name**: `do_gitops`
- **Field Type**: `Multiple Choice (single answer)`
- **Choices**:
  - `true` → `Sí`
  - `false` → `No`
- **Default**: `false`
- **Required**: ✅ Yes

- **Question Name**: `do_export_html`
- **Question Description**: `¿Extraer reportes HTML?`
- **Answer Variable Name**: `do_export_html`
- **Field Type**: `Multiple Choice (single answer)`
- **Choices**:
  - `true` → `Sí`
  - `false` → `No`
- **Default**: `false`
- **Required**: ✅ Yes

- **Question Name**: `do_send_email`
- **Question Description**: `¿Enviar reportes por correo?`
- **Answer Variable Name**: `do_send_email`
- **Field Type**: `Multiple Choice (single answer)`
- **Choices**:
  - `true` → `Sí`
  - `false` → `No`
- **Default**: `false`
- **Required**: ✅ Yes

#### Survey 3: Destinatarios de Correo

- **Question Name**: `email_to`
- **Question Description**: `Destinatarios del correo (separados por comas)`
- **Answer Variable Name**: `email_to`
- **Field Type**: `Text`
- **Required**: ✅ Yes (si `do_send_email=true`)
- **Default Answer**: `admin@empresa.com`

---

## Consideraciones de Seguridad

### 1. Gestión de Secretos

**❌ NO HACER:**
- Poner tokens o contraseñas en Extra Vars en texto plano
- Poner secretos en Surveys
- Hardcodear secretos en playbooks

**✅ HACER:**
- Usar **Environment Variables** para secretos
- Usar **Credentials** de AAP para tokens y contraseñas
- Usar **Source Control Credentials** para GitHub
- Rotar tokens y contraseñas periódicamente

### 2. Permisos Mínimos

- **GitHub Token**: Solo permisos `repo` (no `admin`)
- **OpenShift Token**: Solo permisos de lectura en `openshift-compliance` namespace
- **SMTP**: Usar contraseñas de aplicación (no contraseñas principales)

### 3. Logs y Auditoría

- Las Environment Variables no aparecen en logs
- Los Surveys se registran en el historial de jobs
- Revisar logs periódicamente para detectar accesos no autorizados

### 4. Network Security

- Asegurar que AAP pueda acceder a:
  - Hub Cluster (API endpoint)
  - Repositorio GitOps (GitHub/GitLab)
  - Servidor SMTP
- Usar VPN o firewalls según políticas corporativas

---

## Troubleshooting

### Problema 1: Error "Faltan variables de Git"

**Síntoma:**
```
❌ ERROR: Faltan variables de Git. Defínalas en AAP (Extra Vars, Survey o Credential de Source Control).
```

**Solución:**
1. Verificar que `do_gitops=true`
2. Verificar que `github_user`, `github_token`, `gitops_repo_branch` estén definidas
3. Si usas Environment Variable para `github_token`, verificar que esté configurada en Job Template

### Problema 2: Error "Faltan variables de Correo"

**Síntoma:**
```
❌ ERROR: Faltan variables de Correo. Defínalas en AAP (Extra Vars o Survey).
```

**Solución:**
1. Verificar que `do_send_email=true`
2. Verificar que todas las variables de correo estén definidas
3. Verificar que `email_smtp_password` esté en Environment Variables

### Problema 3: No se encuentran PVCs en los clusters

**Síntoma:**
```
No se encontraron PVCs para procesar
```

**Solución:**
1. Verificar que el Compliance Operator esté instalado en cada managed cluster
2. Verificar que se hayan ejecutado escaneos previamente
3. Verificar que los PVCs existan en el namespace `openshift-compliance`
4. Verificar que el kubeconfig del managed cluster sea correcto

### Problema 4: Error de autenticación SMTP

**Síntoma:**
```
Failed to send email: Authentication failed
```

**Solución:**
1. Para Gmail: Usar "Contraseña de aplicación" (no la contraseña principal)
2. Verificar que `email_smtp_port` sea correcto (587 para STARTTLS)
3. Verificar que `email_smtp_host` sea correcto
4. Verificar que el firewall permita conexiones SMTP

### Problema 4.1: Timeout al enviar correo (pero el correo se envía correctamente)

**Síntoma:**
```
TimeoutError: The read operation timed out
SMTPServerDisconnected: Connection unexpectedly closed: The read operation timed out
```

**Explicación:**
Este es un problema común cuando se envían archivos grandes (ZIPs de reportes). El servidor SMTP procesa y envía el correo correctamente, pero cierra la conexión antes de que el cliente reciba la confirmación, causando un timeout.

**Solución:**
1. **Aumentar el timeout SMTP**: Agregar en Extra Variables:
   ```yaml
   email_smtp_timeout: 90
   ```
   O para archivos muy grandes:
   ```yaml
   email_smtp_timeout: 120
   ```

2. **Verificar recepción**: Aunque la tarea muestre error, el correo generalmente se envía correctamente. Verificar la bandeja de entrada.

3. **El playbook maneja esto automáticamente**: El playbook tiene `ignore_errors: true` y muestra un mensaje informativo indicando que el correo puede haberse enviado a pesar del error.

**Nota**: El timeout por defecto es de 60 segundos. Para archivos de más de 5MB, se recomienda aumentar a 90-120 segundos.

### Problema 5: Error al clonar repositorio GitOps

**Síntoma:**
```
Failed to clone repository: Authentication failed
```

**Solución:**
1. Verificar que el token de GitHub tenga permisos `repo`
2. Verificar que el token no haya expirado
3. Verificar que la URL del repositorio sea correcta
4. Verificar que AAP tenga acceso a GitHub (firewall/proxy)

### Problema 6: Kubeconfig duplicado o incorrecto

**Síntoma:**
```
Todos los clusters usan el mismo kubeconfig
```

**Solución:**
1. Verificar que cada managed cluster tenga su propio Secret en el Hub
2. Verificar que los Secrets tengan nombres únicos
3. Verificar que el namespace del Secret coincida con el nombre del cluster

---

## Ejemplos de Configuración

### Ejemplo 1: Solo Extracción de Reportes (Sin GitOps, Sin Correo)

**Extra Variables:**
```yaml
do_gitops: false
do_export_html: true
do_send_email: false
survey_target_clusters: 
  - cluster-acs
  - cluster-2
```

**Survey:**
- `survey_target_clusters`: `cluster-acs\ncluster-2`

### Ejemplo 2: GitOps + Extracción + Correo (Configuración Completa)

**Extra Variables:**
```yaml
do_gitops: true
do_export_html: true
do_send_email: true
github_user: "mi-usuario"
gitops_repo_branch: "main"
email_smtp_host: "smtp.gmail.com"
email_smtp_port: 587
email_smtp_username: "compliance@empresa.com"
email_from: "compliance@empresa.com"
email_subject_prefix: "Reporte de compliance multicluster"
run_cis: true
run_pci: false
scan_schedule: "0 2 * * *"
```

**Environment Variables:**
```yaml
GITHUB_TOKEN: "ghp_xxxxxxxxxxxx"
EMAIL_SMTP_PASSWORD: "contraseña_aplicacion"
```

**Survey:**
- `survey_target_clusters`: `cluster-acs\ncluster-2`
- `email_to`: `admin@empresa.com,auditor@empresa.com`

### Ejemplo 3: Múltiples Destinatarios de Correo

**Survey - email_to:**
```
admin@empresa.com,compliance@empresa.com,auditor@empresa.com
```

**O en Extra Variables (lista YAML):**
```yaml
email_to:
  - admin@empresa.com
  - compliance@empresa.com
  - auditor@empresa.com
```

---

## Checklist de Aprovisionamiento

### Pre-requisitos
- [ ] AAP instalado y operativo
- [ ] Execution Environment personalizado creado
- [ ] Hub Cluster accesible desde AAP
- [ ] Managed Clusters registrados y en estado `Ready`
- [ ] Compliance Operator instalado en Hub y Managed Clusters
- [ ] Repositorio GitOps creado y accesible (si `do_gitops=true`)
- [ ] Servidor SMTP accesible (si `do_send_email=true`)

### Configuración en AAP
- [ ] Project creado y sincronizado
- [ ] Inventory creado con host `localhost`
- [ ] Credencial de OpenShift/Kubernetes creada
- [ ] Credencial de Source Control creada (si `do_gitops=true`)
- [ ] Environment Variables configuradas (secretos)
- [ ] Job Template creado
- [ ] Extra Variables configuradas
- [ ] Survey configurado (opcional pero recomendado)
- [ ] Permisos de ejecución configurados

### Pruebas
- [ ] Ejecutar Job Template con `do_gitops=false`, `do_export_html=true`, `do_send_email=false`
- [ ] Verificar que se extraigan reportes correctamente
- [ ] Ejecutar con `do_send_email=true` y verificar recepción de correo
- [ ] Ejecutar con `do_gitops=true` y verificar actualización de políticas
- [ ] Verificar logs para detectar errores

---

## Referencias y Documentación Adicional

- [Documentación de AAP](https://docs.ansible.com/automation-platform/)
- [Módulo community.general.mail](https://docs.ansible.com/ansible/latest/collections/community/general/mail_module.html)
- [OpenShift Compliance Operator](https://docs.openshift.com/container-platform/latest/security/compliance_operator/compliance-operator-understanding.html)
- [Advanced Cluster Management](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/)

---

**Última actualización**: 2024-01-XX
**Versión del Playbook**: 1.0
**Autor**: Equipo de Automatización



