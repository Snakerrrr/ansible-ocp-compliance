# Guía Completa de Configuración en Ansible Automation Platform (AAP)

Esta guía te ayudará a configurar todo el ambiente de AAP desde cero para ejecutar el playbook de compliance multi-cluster.

---

## 📋 Tabla de Contenidos

1. [Configuración del Repositorio](#1-configuración-del-repositorio)
2. [Configuración de Credentials](#2-configuración-de-credentials)
3. [Configuración del Execution Environment](#3-configuración-del-execution-environment)
4. [Configuración del Inventory](#4-configuración-del-inventory)
5. [Configuración del Project](#5-configuración-del-project)
6. [Configuración del Job Template](#6-configuración-del-job-template)
7. [Configuración del Survey](#7-configuración-del-survey)
8. [Configuración de Extra Variables](#8-configuración-de-extra-variables)
9. [Configuración de Variables de Entorno](#9-configuración-de-variables-de-entorno)
10. [Verificación y Pruebas](#10-verificación-y-pruebas)

---

## 1. Configuración del Repositorio

### 1.1 Crear el Project en AAP

1. **Navegar a Projects:**
   - Ve a **Resources > Projects**
   - Click en **"Add"** o **"+"**

2. **Configurar el Project:**
   - **Name**: `Compliance Automation - GitOps`
   - **Organization**: Tu organización (ej: `Default`)
   - **Source Control Type**: `Git`
   - **Source Control URL**: `https://github.com/Snakerrrr/ansible-ocp-compliance.git`
     - O tu URL del repositorio
   - **Source Control Branch/Tag/Commit**: `main` (o la rama que uses)
   - **Source Control Credential**: Selecciona el credential de GitHub (ver sección 2.1)
   - **Options**:
     - ✅ **Clean**: Marcado (limpia el workspace antes de cada ejecución)
     - ✅ **Delete on Update**: Marcado (elimina archivos obsoletos)
     - ✅ **Update Revision on Launch**: Marcado (actualiza el código antes de ejecutar)
   - **Description**: `Repositorio principal para automatización de compliance en OpenShift`

3. **Guardar y Sincronizar:**
   - Click en **"Save"**
   - Click en **"Sync Project"** para verificar que puede clonar el repositorio

---

## 2. Configuración de Credentials

### 2.1 Credential de GitHub (Source Control) ⭐ RECOMENDADO

**Propósito**: Clonar el repositorio y hacer push de cambios GitOps.

1. **Crear el Credential:**
   - Ve a **Resources > Credentials**
   - Click en **"Add"** o **"+"**
   - Selecciona tipo: **"Source Control"**

2. **Configuración:**
   - **Name**: `GitHub Token - Compliance GitOps`
   - **Organization**: Tu organización
   - **Credential Type**: `Source Control`
   - **Type**: `Git`
   - **Username**: Tu usuario de GitHub (ej: `Snakerrrr`)
   - **Password/Token**: Tu Personal Access Token de GitHub
     - Generar token: https://github.com/settings/tokens
     - Permisos necesarios: `repo` (acceso completo a repositorios privados)
   - **Description**: `Token para operaciones GitOps de Compliance`

3. **Guardar:**
   - Click en **"Save"**

**Nota**: Este credential se usará en el Project (sección 1.1) y opcionalmente en el Job Template.

---

### 2.2 Credential de Kubernetes (Kubernetes Bearer Token)

**Propósito**: Conectarse al cluster Hub de OpenShift/ACM para acceder a los managed clusters.

1. **Crear el Credential:**
   - Ve a **Resources > Credentials**
   - Click en **"Add"** o **"+"**
   - Selecciona tipo: **"Kubernetes Bearer Token"**

2. **Configuración:**
   - **Name**: `OpenShift Hub - Bearer Token`
   - **Organization**: Tu organización
   - **Credential Type**: `Kubernetes Bearer Token`
   - **Authentication**: Selecciona una de estas opciones:

   **Opción A: Usar kubeconfig (Recomendado para desarrollo)**
   - **Configuration File Path**: Dejar vacío (AAP usará el kubeconfig del Pod)
   - O pegar el contenido completo de tu `~/.kube/config` del Hub

   **Opción B: Usar Token directamente**
   - **OpenShift or Kubernetes API Endpoint**: `https://api.hub-cluster.example.com:6443`
   - **Token**: Tu token de servicio o token de usuario
     - Obtener token: `oc whoami -t` desde el Hub

   - **Description**: `Credencial para acceder al cluster Hub de OpenShift/ACM`

3. **Guardar:**
   - Click en **"Save"**

**Nota**: Este credential se asociará al Job Template para que el playbook pueda ejecutar comandos `oc` y acceder a la API de Kubernetes.

---

## 3. Configuración del Execution Environment

### 3.1 Usar Execution Environment Estándar (Recomendado para empezar)

**Opción A: Usar el EE por defecto de AAP**

1. **Verificar EE disponible:**
   - Ve a **Administration > Execution Environments**
   - Busca `Default execution environment` o `awx-ee:latest`
   - Si no existe, AAP usará el EE por defecto del sistema

2. **Verificar que incluye:**
   - Python 3.x
   - Módulos de Ansible: `community.general` (para `mail` y `archive`)
   - Módulos de Kubernetes: `kubernetes.core` (para `k8s_info`)

**Nota**: El EE estándar de AAP (`quay.io/ansible/awx-ee:latest`) incluye estos módulos por defecto.

---

### 3.2 Crear Execution Environment Personalizado (Opcional)

Si necesitas dependencias adicionales:

1. **Crear archivo `execution-environment.yml`:**
   ```yaml
   version: 1
   
   build_arg_defaults:
     EE_BASE_IMAGE: quay.io/ansible/awx-ee:latest
   
   dependencies:
     galaxy: requirements.yml
     python: requirements.txt
   
   additional_build_steps:
     append_final:
       - RUN pip install --upgrade pip
       - RUN pip install kubernetes
   ```

2. **Construir y subir el EE:**
   - Usar `ansible-builder` para construir la imagen
   - Subirla a un registry (ej: `quay.io` o registry interno)
   - Crear el EE en AAP apuntando a esa imagen

3. **Asociar al Job Template:**
   - En el Job Template, seleccionar este EE personalizado

---

## 4. Configuración del Inventory

### 4.1 Crear Inventory

1. **Navegar a Inventories:**
   - Ve a **Resources > Inventories**
   - Click en **"Add"** o **"+"**
   - Selecciona **"Add inventory"**

2. **Configuración:**
   - **Name**: `Compliance Automation - Localhost`
   - **Organization**: Tu organización
   - **Description**: `Inventory para ejecutar playbooks en localhost (AAP Runner)`

3. **Guardar:**
   - Click en **"Save"**

---

### 4.2 Agregar Host

1. **Agregar Host:**
   - Dentro del Inventory, ve a la pestaña **"Hosts"**
   - Click en **"Add"** o **"+"**
   - Click en **"Add new host"**

2. **Configuración del Host:**
   - **Name**: `localhost`
   - **Description**: `Host local para ejecución en el Runner de AAP`
   - **Variables** (opcional):
     ```yaml
     ansible_connection: local
     ansible_python_interpreter: auto_silent
     ```

3. **Guardar:**
   - Click en **"Save"**

---

## 5. Configuración del Project

Ya deberías haber creado el Project en la sección 1.1. Verifica que:

- ✅ El Project está sincronizado correctamente
- ✅ El credential de GitHub está asociado
- ✅ La rama es `main` (o la correcta)
- ✅ El Project se puede actualizar manualmente (botón "Sync Project")

---

## 6. Configuración del Job Template

### 6.1 Crear el Job Template

1. **Navegar a Templates:**
   - Ve a **Resources > Templates**
   - Click en **"Add"** o **"+"**
   - Selecciona **"Add job template"**

2. **Configuración Básica:**
   - **Name**: `Compliance Pipeline - Multi-Cluster`
   - **Description**: `Orquestador para ejecutar compliance en múltiples clusters OpenShift`
   - **Job Type**: `Run`
   - **Inventory**: Selecciona el inventory creado en la sección 4 (`Compliance Automation - Localhost`)
   - **Project**: Selecciona el project creado en la sección 1.1 (`Compliance Automation - GitOps`)
   - **Playbook**: `playbooks/orchestrator_aap_multicluster.yml`
   - **Execution Environment**: Selecciona el EE (sección 3.1 o 3.2)
   - **Forks**: `1` (suficiente para localhost)
   - **Limit**: (dejar vacío)
   - **Verbosity**: `0` (Normal) o `1` (Verbose) para debugging

3. **Configuración de Credentials:**
   - En la sección **"Credentials"**, click en **"+"**
   - Agrega:
     - ✅ **Kubernetes Bearer Token**: `OpenShift Hub - Bearer Token` (sección 2.2)
     - ✅ **Source Control** (opcional): `GitHub Token - Compliance GitOps` (sección 2.1)
       - Solo si quieres que el playbook use el token del credential en lugar del Survey

4. **Opciones:**
   - ✅ **Enable Privilege Escalation**: Desmarcado (no necesario para localhost)
   - ✅ **Enable Fact Cache**: Desmarcado (no necesario)
   - ✅ **Enable Concurrent Jobs**: Marcado (permite ejecuciones paralelas)
   - ✅ **Enable Webhooks**: Desmarcado (a menos que uses webhooks)

5. **Guardar:**
   - Click en **"Save"**

---

## 7. Configuración del Survey

El Survey permite que los usuarios ingresen valores dinámicos al ejecutar el job.

### 7.1 Habilitar Survey

1. **Ir al Job Template:**
   - Ve a tu Job Template: `Compliance Pipeline - Multi-Cluster`
   - Click en la pestaña **"Survey"**

2. **Habilitar Survey:**
   - Click en **"Add survey"** o **"Enable Survey"**

---

### 7.2 Agregar Preguntas del Survey

Agrega las siguientes preguntas en este orden:

#### Pregunta 1: Clusters a Auditar

- **Variable name**: `survey_target_clusters`
- **Question**: `Selecciona los clusters a auditar`
- **Answer variable name**: `survey_target_clusters`
- **Field type**: `Multiple Choice (multiple select)`
- **Choices** (una por línea):
  ```
  cluster-acs
  cluster-2
  cluster-3
  ```
  (Agrega todos tus clusters managed)
- **Default**: (dejar vacío)
- **Required**: ✅ Marcado
- **Description**: `Lista de clusters donde se ejecutará la auditoría de compliance`

---

#### Pregunta 2: Activar GitOps

- **Variable name**: `do_gitops`
- **Question**: `¿Aplicar cambios en GitOps?`
- **Answer variable name**: `do_gitops`
- **Field type**: `Multiple Choice (single select)`
- **Choices** (una por línea):
  ```
  true
  false
  ```
- **Default**: `false`
- **Required**: ✅ Marcado
- **Description**: `Si está activado, actualizará las políticas en el repositorio GitOps y hará commit/push`

---

#### Pregunta 3: Activar Export HTML

- **Variable name**: `do_export_html`
- **Question**: `¿Exportar reportes HTML?`
- **Answer variable name**: `do_export_html`
- **Field type**: `Multiple Choice (single select)`
- **Choices** (una por línea):
  ```
  true
  false
  ```
- **Default**: `true`
- **Required**: ✅ Marcado
- **Description**: `Si está activado, generará reportes HTML desde los resultados de compliance`

---

#### Pregunta 4: Activar Envío de Correo

- **Variable name**: `do_send_email`
- **Question**: `¿Enviar reportes por correo electrónico?`
- **Answer variable name**: `do_send_email`
- **Field type**: `Multiple Choice (single select)`
- **Choices** (una por línea):
  ```
  true
  false
  ```
- **Default**: `false`
- **Required**: ✅ Marcado
- **Description**: `Si está activado, enviará los reportes comprimidos (ZIP) por correo. Requiere configuración SMTP.`

---

#### Pregunta 5: Usuario de GitHub (Opcional)

- **Variable name**: `github_user`
- **Question**: `Usuario de GitHub (opcional)`
- **Answer variable name**: `github_user`
- **Field type**: `Text`
- **Default**: `Snakerrrr` (o tu usuario por defecto)
- **Required**: ❌ Desmarcado
- **Description**: `Usuario de GitHub para operaciones GitOps. Si está vacío, se usará el valor por defecto.`

---

#### Pregunta 6: Rama del Repositorio GitOps (Opcional)

- **Variable name**: `gitops_repo_branch`
- **Question**: `Rama del repositorio GitOps (opcional)`
- **Answer variable name**: `gitops_repo_branch`
- **Field type**: `Text`
- **Default**: `main`
- **Required**: ❌ Desmarcado
- **Description**: `Rama del repositorio GitOps donde se aplicarán los cambios`

---

#### Pregunta 7: Token de GitHub (Opcional - Solo si no usas Credential)

- **Variable name**: `github_token`
- **Question**: `Token de GitHub (opcional)`
- **Answer variable name**: `github_token`
- **Field type**: `Password` ⭐ (IMPORTANTE: Usar tipo Password para ocultar el token)
- **Default**: (dejar vacío)
- **Required**: ❌ Desmarcado
- **Description**: `Personal Access Token de GitHub. Solo necesario si no se usa el Credential de Source Control. Si está vacío, se intentará usar el Credential.`

---

#### Pregunta 8: Habilitar Escaneo CIS

- **Variable name**: `run_cis`
- **Question**: `¿Habilitar escaneo CIS?`
- **Answer variable name**: `run_cis`
- **Field type**: `Multiple Choice (single select)`
- **Choices**:
  ```
  true
  false
  ```
- **Default**: `true`
- **Required**: ✅ Marcado
- **Description**: `Habilita o deshabilita el escaneo CIS en los clusters`

---

#### Pregunta 9: Habilitar Escaneo PCI

- **Variable name**: `run_pci`
- **Question**: `¿Habilitar escaneo PCI-DSS?`
- **Answer variable name**: `run_pci`
- **Field type**: `Multiple Choice (single select)`
- **Choices**:
  ```
  true
  false
  ```
- **Default**: `false`
- **Required**: ✅ Marcado
- **Description**: `Habilita o deshabilita el escaneo PCI-DSS en los clusters`

---

#### Pregunta 10: Schedule de Escaneos (Opcional)

- **Variable name**: `scan_schedule`
- **Question**: `Schedule de escaneos (formato cron)`
- **Answer variable name**: `scan_schedule`
- **Field type**: `Text`
- **Default**: `0 1 * * *` (1 AM diario)
- **Required**: ❌ Desmarcado
- **Description**: `Schedule en formato cron para ejecutar los escaneos. Ejemplo: "0 1 * * *" (diario a la 1 AM)`

---

### 7.3 Guardar el Survey

1. **Revisar preguntas:**
   - Verifica que todas las preguntas estén configuradas correctamente
   - Verifica que los tipos de campo sean correctos (especialmente `Password` para tokens)

2. **Guardar:**
   - Click en **"Save"**

3. **Habilitar Survey:**
   - Asegúrate de que el Survey esté **habilitado** (toggle en la parte superior)

---

## 8. Configuración de Extra Variables

Las Extra Variables se pueden definir en el Job Template para valores que no cambian frecuentemente.

### 8.1 Agregar Extra Variables en el Job Template

1. **Ir al Job Template:**
   - Ve a tu Job Template: `Compliance Pipeline - Multi-Cluster`
   - Click en la pestaña **"Details"** o **"Variables"**

2. **Agregar Extra Variables:**
   - Busca la sección **"Extra Variables"** o **"Variables"**
   - Agrega las siguientes variables (formato YAML):

```yaml
# --- CONFIGURACIÓN DE COMPLIANCE ---
scan_remediation_action: "inform"
install_operator_remediation_action: "enforce"
scan_setting_name: "periodic-daily"

# --- CONFIGURACIÓN DE PLACEMENT (Labels para seleccionar clusters) ---
placement_label_key: "compliance"
placement_label_value: "enabled"
placement_use_matchlabels: true

# --- CONFIGURACIÓN DE CORREO (Solo si no usas Variables de Entorno) ---
# ⚠️ NO pongas passwords aquí - usa Variables de Entorno (sección 9)
email_smtp_host: "smtp.gmail.com"
email_smtp_port: 587
email_from: "compliance-automation@banorte.com"
email_subject_prefix: "Reporte de Compliance"
# email_smtp_username: (usar Variable de Entorno)
# email_smtp_password: (usar Variable de Entorno)
# email_to: (usar Survey o Variable de Entorno)
```

**⚠️ IMPORTANTE**: No pongas passwords ni tokens en Extra Variables, ya que aparecen en los logs. Usa Variables de Entorno (sección 9) o Credentials.

---

## 9. Configuración de Variables de Entorno

Las Variables de Entorno son la forma más segura de manejar credenciales sensibles.

### 9.1 Agregar Variables de Entorno en el Job Template

1. **Ir al Job Template:**
   - Ve a tu Job Template: `Compliance Pipeline - Multi-Cluster`
   - Click en la pestaña **"Details"**

2. **Agregar Variables de Entorno:**
   - Busca la sección **"Environment Variables"** o **"Variables de Entorno"**
   - Agrega las siguientes variables (formato KEY=VALUE, una por línea):

```bash
# --- CREDENCIALES SMTP (Para envío de correo) ---
EMAIL_SMTP_HOST=smtp.gmail.com
EMAIL_SMTP_PORT=587
EMAIL_SMTP_USERNAME=compliance-automation@banorte.com
EMAIL_SMTP_PASSWORD=xxxx xxxx xxxx xxxx
EMAIL_TO=bastian@banorte.com
EMAIL_FROM=compliance-automation@banorte.com

# --- TOKEN DE GITHUB (Opcional - Solo si no usas Credential) ---
# GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Nota**: 
- Para Gmail, `EMAIL_SMTP_PASSWORD` debe ser una **Contraseña de Aplicación** (ver sección 9.2)
- El playbook leerá estas variables usando `lookup('env', 'VARIABLE_NAME')`

---

### 9.2 Configurar Contraseña de Aplicación para Gmail

Si usas Gmail como servidor SMTP:

1. **Habilitar Verificación en 2 pasos:**
   - Ve a: https://myaccount.google.com/security
   - Activa **"Verificación en 2 pasos"**

2. **Generar Contraseña de Aplicación:**
   - Ve a: https://myaccount.google.com/apppasswords
   - Genera una contraseña para **"Correo"**
   - Copia la contraseña generada (16 caracteres, formato: `xxxx xxxx xxxx xxxx`)

3. **Usar en Variables de Entorno:**
   - Pega la contraseña en `EMAIL_SMTP_PASSWORD` (sin espacios o con espacios, ambos funcionan)

---

## 10. Verificación y Pruebas

### 10.1 Checklist de Configuración

Antes de ejecutar el job, verifica:

- [ ] ✅ Project está sincronizado y puede clonar el repositorio
- [ ] ✅ Credential de GitHub está creado y asociado al Project
- [ ] ✅ Credential de Kubernetes está creado y asociado al Job Template
- [ ] ✅ Inventory tiene el host `localhost`
- [ ] ✅ Job Template apunta al playbook correcto: `playbooks/orchestrator_aap_multicluster.yml`
- [ ] ✅ Execution Environment está seleccionado
- [ ] ✅ Survey está habilitado y tiene todas las preguntas configuradas
- [ ] ✅ Extra Variables están configuradas (si aplica)
- [ ] ✅ Variables de Entorno están configuradas (si usas correo)

---

### 10.2 Prueba de Ejecución Básica

1. **Ejecutar Job:**
   - Ve a tu Job Template: `Compliance Pipeline - Multi-Cluster`
   - Click en **"Launch"** o **"Ejecutar"**

2. **Completar Survey:**
   - Selecciona al menos un cluster (ej: `cluster-acs`)
   - `do_gitops`: `false` (para la primera prueba)
   - `do_export_html`: `true`
   - `do_send_email`: `false` (para la primera prueba)
   - `run_cis`: `true`
   - `run_pci`: `false`
   - Click en **"Next"** y luego **"Launch"**

3. **Monitorear Ejecución:**
   - Observa los logs en tiempo real
   - Verifica que no haya errores de conexión
   - Verifica que el playbook encuentre los clusters

---

### 10.3 Prueba con GitOps

1. **Configurar Survey:**
   - `do_gitops`: `true`
   - `github_user`: Tu usuario (o dejar por defecto)
   - `gitops_repo_branch`: `main`
   - `github_token`: (dejar vacío si usas Credential, o ingresar token si no)

2. **Ejecutar:**
   - Click en **"Launch"**
   - Verifica que:
     - El repositorio se clona correctamente
     - Los archivos YAML se generan
     - Se hace commit y push al repositorio

---

### 10.4 Prueba con Envío de Correo

1. **Configurar Variables de Entorno:**
   - Asegúrate de que `EMAIL_SMTP_*` estén configuradas (sección 9.1)

2. **Configurar Survey:**
   - `do_export_html`: `true`
   - `do_send_email`: `true`

3. **Ejecutar:**
   - Click en **"Launch"**
   - Verifica que:
     - Los reportes se generan
     - Se crea el archivo ZIP
     - Se envía el correo con el ZIP adjunto

---

## 11. Troubleshooting Común

### Error: "The role 'gitops_policy_update' was not found"

**Causa**: El playbook no encuentra los roles.

**Solución**: 
- Verifica que el Project esté sincronizado correctamente
- Verifica que la estructura del repositorio sea correcta (`roles/` debe existir)
- Verifica que el playbook esté en `playbooks/orchestrator_aap_multicluster.yml`

---

### Error: "github_token is not defined"

**Causa**: El token de GitHub no está disponible.

**Solución**:
- Verifica que el Credential de Source Control esté asociado al Job Template
- O agrega `github_token` en el Survey o Variables de Entorno
- Verifica que `do_gitops=true` en el Survey

---

### Error: "email_smtp_password is not defined"

**Causa**: Las credenciales SMTP no están configuradas.

**Solución**:
- Agrega las Variables de Entorno `EMAIL_SMTP_*` (sección 9.1)
- O agrega `email_smtp_*` en Extra Variables (no recomendado para passwords)
- Verifica que `do_send_email=true` en el Survey

---

### Error: "Authentication failed" al enviar correo

**Causa**: Credenciales SMTP incorrectas.

**Solución**:
- Para Gmail: Usa una **Contraseña de Aplicación**, no tu contraseña normal
- Verifica que el usuario y password sean correctos
- Verifica que el servidor SMTP sea accesible desde AAP

---

### Error: "The loop variable 'item' is already in use"

**Causa**: Conflicto de variables en loops anidados.

**Solución**: Ya está corregido en el código. Asegúrate de tener la versión más reciente del repositorio.

---

### Los reportes no se envían por correo

**Causa**: El módulo `mail` no está disponible o las credenciales no están configuradas.

**Solución**:
1. Verifica que el Execution Environment incluya `community.general.mail`
2. Verifica que `do_send_email=true` en el Survey
3. Verifica que todas las Variables de Entorno SMTP estén configuradas
4. Revisa los logs del job para ver el error específico

---

## 12. Resumen de Variables por Origen

### Variables del Survey (Dinámicas - Usuario las ingresa):
- `survey_target_clusters`: Lista de clusters
- `do_gitops`: Activar GitOps
- `do_export_html`: Activar export HTML
- `do_send_email`: Activar envío de correo
- `github_user`: Usuario de GitHub (opcional)
- `gitops_repo_branch`: Rama GitOps (opcional)
- `github_token`: Token de GitHub (opcional, mejor usar Credential)
- `run_cis`: Habilitar CIS
- `run_pci`: Habilitar PCI
- `scan_schedule`: Schedule cron (opcional)

### Variables de Extra Variables (Fijas):
- `scan_remediation_action`: "inform" o "enforce"
- `install_operator_remediation_action`: "enforce"
- `scan_setting_name`: "periodic-daily"
- `placement_label_key`: "compliance"
- `placement_label_value`: "enabled"
- `placement_use_matchlabels`: true
- `email_smtp_host`: Servidor SMTP (si no usas Variables de Entorno)
- `email_smtp_port`: Puerto SMTP
- `email_from`: Remitente
- `email_subject_prefix`: Prefijo del asunto

### Variables de Variables de Entorno (Seguras - Para passwords):
- `EMAIL_SMTP_HOST`: Servidor SMTP
- `EMAIL_SMTP_PORT`: Puerto SMTP
- `EMAIL_SMTP_USERNAME`: Usuario SMTP
- `EMAIL_SMTP_PASSWORD`: Password SMTP (Contraseña de Aplicación para Gmail)
- `EMAIL_TO`: Destinatario
- `EMAIL_FROM`: Remitente
- `GITHUB_TOKEN`: Token de GitHub (opcional, mejor usar Credential)

### Variables de Credentials (Más Seguras):
- **Source Control Credential**: Inyecta `GIT_TOKEN` o `SCM_TOKEN` automáticamente
- **Kubernetes Bearer Token**: Permite acceso al cluster Hub

---

## 13. Mejores Prácticas

1. **✅ Usa Credentials para tokens y passwords**: No los pongas en Extra Variables ni Survey
2. **✅ Usa Variables de Entorno para passwords SMTP**: Más seguro que Extra Variables
3. **✅ Usa Survey para valores dinámicos**: Clusters, flags de activación, etc.
4. **✅ Usa Extra Variables para valores fijos**: Configuración de compliance, schedules, etc.
5. **✅ Rota tokens periódicamente**: Especialmente tokens de GitHub y passwords SMTP
6. **✅ Prueba primero con un cluster**: Antes de ejecutar en producción
7. **✅ Revisa los logs**: Si algo falla, los logs mostrarán el error específico
8. **✅ Mantén el repositorio actualizado**: Sincroniza el Project regularmente

---

## 14. Ejemplo de Configuración Completa

### Job Template: `Compliance Pipeline - Multi-Cluster`

**Details:**
- Name: `Compliance Pipeline - Multi-Cluster`
- Inventory: `Compliance Automation - Localhost`
- Project: `Compliance Automation - GitOps`
- Playbook: `playbooks/orchestrator_aap_multicluster.yml`
- Execution Environment: `Default execution environment`

**Credentials:**
- `OpenShift Hub - Bearer Token` (Kubernetes Bearer Token)
- `GitHub Token - Compliance GitOps` (Source Control) - Opcional

**Extra Variables:**
```yaml
scan_remediation_action: "inform"
install_operator_remediation_action: "enforce"
scan_setting_name: "periodic-daily"
placement_label_key: "compliance"
placement_label_value: "enabled"
placement_use_matchlabels: true
email_smtp_host: "smtp.gmail.com"
email_smtp_port: 587
email_from: "compliance-automation@banorte.com"
email_subject_prefix: "Reporte de Compliance"
```

**Environment Variables:**
```bash
EMAIL_SMTP_HOST=smtp.gmail.com
EMAIL_SMTP_PORT=587
EMAIL_SMTP_USERNAME=compliance-automation@banorte.com
EMAIL_SMTP_PASSWORD=xxxx xxxx xxxx xxxx
EMAIL_TO=bastian@banorte.com
EMAIL_FROM=compliance-automation@banorte.com
```

**Survey:**
- ✅ `survey_target_clusters` (Multiple Choice - Multiple Select)
- ✅ `do_gitops` (Multiple Choice - Single Select, default: false)
- ✅ `do_export_html` (Multiple Choice - Single Select, default: true)
- ✅ `do_send_email` (Multiple Choice - Single Select, default: false)
- ✅ `run_cis` (Multiple Choice - Single Select, default: true)
- ✅ `run_pci` (Multiple Choice - Single Select, default: false)
- ✅ `scan_schedule` (Text, default: "0 1 * * *")

---

## 15. Documentación Adicional

Para más detalles sobre configuraciones específicas, consulta:

- **[CONFIGURACION-EMAIL-AAP.md](CONFIGURACION-EMAIL-AAP.md)**: Configuración detallada de correo
- **[CONFIGURACION-GITHUB-TOKEN-AAP.md](CONFIGURACION-GITHUB-TOKEN-AAP.md)**: Configuración detallada de GitHub token
- **[README.md](README.md)**: Documentación general del proyecto
- **[EJECUTAR-PLAYBOOK.md](EJECUTAR-PLAYBOOK.md)**: Guía de ejecución desde línea de comandos

---

**¡Listo!** Con esta configuración, deberías poder ejecutar el playbook de compliance multi-cluster desde AAP. Si encuentras algún problema, revisa la sección de Troubleshooting o los logs del job.










