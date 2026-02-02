# Ansible OpenShift Compliance Automation

Automatización de compliance para OpenShift usando Ansible, el Compliance Operator de OpenShift y GitOps con ACM (Advanced Cluster Management).

## Descripción

Este proyecto automatiza la gestión de compliance en entornos OpenShift multi-cluster mediante:

- **GitOps**: Configuración declarativa de políticas de compliance usando PolicyGenerator de ACM
- **Compliance Operator**: Escaneos automáticos y periódicos de compliance (CIS, PCI-DSS)
- **Exportación de Reportes**: Generación de reportes HTML desde los resultados de compliance
  - Soporta estándares específicos: `ocp4-pci-dss-4-0`, `ocp4-pci-dss-node-4-0-*`, `ocp4-cis-1-7`, `ocp4-cis-node-1-7-*`
- **Controles de Seguridad**: Playbooks especializados para informar y aplicar controles de seguridad
  - **Inform**: Revisión y reporte de controles de seguridad (kubeadmin, logs, ingress, LDAP, ACS, network policies, OAuth, remediaciones)
  - **Enforce**: Aplicación automática de remediaciones y configuración de controles (OAuth timeouts, ComplianceRemediations)
- **Multi-cluster**: Soporte para ejecución en múltiples clusters gestionados desde un Hub
- **Entrega de Reportes**: Push de reportes a GitLab (orquestador: ZIPs en `reports/<nombre_cluster>/`; Inform/Enforce: reportes TXT en `reportes_controles_seguridad/<nombre_cluster>/inform/` o `.../enforce/`, reteniendo los 5 más recientes por carpeta)
- **Conexión Hub-to-Spoke**: Los roles extraen el kubeconfig del managed cluster desde el Hub con `kubernetes.core.k8s_info` (secret `admin-kubeconfig`) y fuerzan el uso de ese kubeconfig en todas las tareas (anulando K8S_AUTH_* del Job) para consultar el spoke, no el Hub
- **100% Agnóstico**: Sin valores hardcodeados, todas las variables se inyectan desde AAP
- **Mejores Prácticas**: Todos los módulos de Ansible utilizan FQDN (Fully Qualified Domain Names) para mayor claridad y compatibilidad

## Estructura del Proyecto

```
.
├── playbooks/                              # Playbooks principales
│   ├── orchestrator_aap_multicluster.yml   # Orquestador multi-cluster (GitOps, export HTML, push GitLab)
│   ├── enforce.yaml                        # Playbook para aplicar controles de seguridad (enforce)
│   ├── inform.yaml                         # Playbook para informar sobre controles de seguridad (inform)
│   └── GUIA_ACTUALIZACION_AAP_GITLAB.md    # Guía de configuración en AAP (variables, credenciales, Survey)
├── roles/                                  # Roles de Ansible
│   ├── gitops_policy_update/               # Actualización de políticas GitOps
│   │   ├── defaults/
│   │   │   └── main.yml                    # Variables por defecto del rol
│   │   └── tasks/
│   │       └── main.yml                    # Tareas de actualización GitOps
│   ├── toggle_policies/                    # Generación de configuraciones (PolicyGenerator, ScanSetting)
│   │   ├── defaults/
│   │   │   └── main.yml                    # Variables por defecto del rol
│   │   ├── tasks/
│   │   │   └── main.yml                    # Tareas de generación de políticas
│   │   └── templates/
│   │       ├── policy-generator-config.yaml.j2  # Template de PolicyGenerator
│   │       └── scan-setting.yaml.j2            # Template de ScanSetting
│   ├── compliance_wait/                    # Espera de instalación del Compliance Operator
│   │   └── tasks/
│   │       └── main.yml                    # Tareas de espera
│   ├── compliance_export_html/             # Exportación de reportes HTML desde PVCs
│   │   ├── defaults/
│   │   │   └── main.yml                    # Variables por defecto del rol
│   │   ├── tasks/
│   │   │   ├── main.yml                    # Tareas principales de exportación
│   │   │   └── process_pvc.yml            # Procesamiento de PVCs
│   │   └── templates/
│   │       ├── extract-kubeconfig.sh.j2   # Script para extraer kubeconfig
│   │       ├── extract-pod.yaml.j2        # Template de Pod para extracción
│   │       ├── render_reports.sh.j2       # Script para renderizar reportes HTML
│   │       └── summary.txt.j2             # Template de resumen
│   ├── controles-seguridad-enforce/        # Aplicación de controles de seguridad (enforce)
│   │   ├── defaults/
│   │   │   └── main.yaml                   # Variables por defecto del rol
│   │   ├── tasks/
│   │   │   ├── main.yml                    # Entrada: iteración sobre target_clusters_list
│   │   │   ├── process_cluster.yml         # Lógica por cluster (Hub-to-Spoke, enforce, reporte GitLab)
│   │   │   ├── remediaciones_automaticas_enforce.yaml
│   │   │   ├── 071_oauth_timeouts_enforce.yml
│   │   │   └── 99_send_report.yml          # Generación de reporte TXT y push a GitLab
│   │   └── templates/
│   │       └── report_final.j2             # Template de reporte final
│   └── controles-seguridad-inform/         # Información sobre controles de seguridad (inform)
│       ├── defaults/
│       │   └── main.yaml                   # Variables por defecto del rol
│       ├── tasks/
│       │   ├── main.yml                    # Entrada: iteración sobre target_clusters_list
│       │   ├── process_cluster.yml         # Lógica por cluster (Hub-to-Spoke, inform, reporte GitLab)
│       │   ├── 01_kubeadmin.yml            # Revisión de kubeadmin
│       │   ├── 02_log_forwarder.yml        # Revisión de log forwarder
│       │   ├── 03_ingress_tls.yml          # Revisión de TLS en ingress
│       │   ├── 04_ldap_tls.yml             # Revisión de TLS en LDAP
│       │   ├── 05_acs_sensor.yml           # Revisión de ACS sensor
│       │   ├── 06_network_policies.yml     # Revisión de network policies
│       │   ├── 07_oauth_timeouts_inform.yml
│       │   ├── automatic_remediation_inform.yml
│       │   └── 99_send_report.yml          # Generación de reporte TXT y push a GitLab
│       └── templates/
│           └── report_final.j2             # Template de reporte final
├── ee-compliance/                          # Execution Environment personalizado
│   ├── execution-environment.yml          # Configuración del EE
│   ├── requirements.yml                   # Dependencias de Ansible (colecciones)
│   ├── bindep.txt                        # Dependencias del sistema (bindep)
│   └── context/                          # Contexto para construir el EE
│       ├── Dockerfile                    # Dockerfile del EE
│       └── _build/                       # Archivos de construcción
│           ├── bindep.txt                # Bindep para construcción
│           ├── requirements.yml          # Requirements para construcción
│           └── scripts/                 # Scripts de construcción
│               ├── assemble              # Script de ensamblado
│               ├── check_ansible         # Verificación de Ansible
│               ├── check_galaxy          # Verificación de Galaxy
│               ├── entrypoint            # Punto de entrada
│               ├── install-from-bindep   # Instalación desde bindep
│               ├── introspect.py         # Script de introspección
│               └── pip_install          # Instalación de pip
├── inventories/                           # Inventarios de Ansible
│   └── localhost.yml                     # Inventario localhost
└── ansible.cfg                            # Configuración de Ansible
```

## Requisitos

### Infraestructura

- **OpenShift Hub Cluster** (ACM Hub) con:
  - Advanced Cluster Management (ACM) instalado y configurado
  - Compliance Operator instalado en el Hub
  - Managed Clusters registrados y en estado `Ready`
  - Acceso desde AAP al Hub Cluster (kubeconfig o Bearer Token)

- **Managed Clusters** con:
  - Compliance Operator instalado en cada cluster
  - Namespace `openshift-compliance` creado
  - PVCs de compliance generados (resultado de escaneos previos)

### Ansible Automation Platform (AAP)

- **AAP 2.x o superior** instalado y operativo
- **Execution Environment** personalizado (ver `ee-compliance/`)
- **Repositorio GitOps** (opcional, solo si `do_gitops=true`)

### Execution Environment Personalizado

El Execution Environment debe incluir las siguientes dependencias:

#### Colecciones de Ansible

- `kubernetes.core` - Para operaciones con Kubernetes/OpenShift
- `ansible.posix` - Para operaciones de sistema POSIX
- `community.general` - Para módulo `archive` (comprimir reportes)

#### Paquetes del Sistema

- `openscap-scanner` - Para generar reportes HTML desde XML de compliance
- `bzip2` - Para descomprimir archivos `.bzip2`
- `zip` - Para comprimir reportes en formato ZIP
- `unzip` - Para descomprimir archivos ZIP
- `git` - Para operaciones GitOps
- `gcc` - Compilador C (requerido para algunas dependencias Python)
- `python3-devel` - Headers de desarrollo de Python
- `libxml2-devel` - Headers de desarrollo de libxml2 (requerido para openscap)
- `libxslt-devel` - Headers de desarrollo de libxslt (requerido para openscap)

#### Herramientas CLI

- `oc` (OpenShift CLI) - Para interactuar con clusters OpenShift
- `tar` - Para operaciones de archivo

**Nota**: Ver `ee-compliance/` para el Dockerfile y configuración completa del Execution Environment.

## Uso Rápido

### Ejecución desde Ansible Automation Platform (AAP)

**Recomendado para producción**. 

1. Configurar Execution Environment
2. Crear credenciales (Hub ACM/OpenShift, GitHub para GitOps, GitLab para push de reportes, Git para el Proyecto)
3. Configurar Job Template con Survey (`survey_target_clusters` para clusters; variables GitLab si se usa push a GitLab)
4. Ejecutar desde AAP UI

**Guía detallada**: Ver `playbooks/GUIA_ACTUALIZACION_AAP_GITLAB.md` para checklist de variables a eliminar/agregar, credenciales y Survey (incluye opción multi-select para clusters).

### Ejecución desde línea de comandos (Desarrollo/Testing)

#### Playbook Orquestador Multi-Cluster

```bash
# Ejecutar solo GitOps (actualizar políticas)
ansible-playbook playbooks/orchestrator_aap_multicluster.yml \
  -e "do_gitops=true" \
  -e "github_user=tu_usuario" \
  -e "github_token=tu_token" \
  -e "gitops_repo_branch=main" \
  -e "survey_target_clusters=cluster-acs,cluster-2"

# Ejecutar solo export HTML (generar reportes)
ansible-playbook playbooks/orchestrator_aap_multicluster.yml \
  -e "do_export_html=true" \
  -e "survey_target_clusters=cluster-acs,cluster-2"

# Ejecutar ambos (GitOps + Export HTML)
ansible-playbook playbooks/orchestrator_aap_multicluster.yml \
  -e "do_gitops=true" \
  -e "do_export_html=true" \
  -e "github_user=tu_usuario" \
  -e "github_token=tu_token" \
  -e "gitops_repo_branch=main" \
  -e "survey_target_clusters=cluster-acs,cluster-2"

# Ejecutar con push de reportes a GitLab
ansible-playbook playbooks/orchestrator_aap_multicluster.yml \
  -e "do_export_html=true" \
  -e "do_push_gitlab=true" \
  -e "survey_target_clusters=cluster-acs,cluster-2" \
  -e "gitlab_repo_url=https://gitlab.com/mi-org/compliance-reports" \
  -e "gitlab_token=tu_token" \
  -e "gitlab_user=ansible-bot" \
  -e "git_workdir=/tmp/compliance-reports-git"
```

#### Playbook Inform (Revisión de Controles de Seguridad)

Los playbooks Inform y Enforce esperan `survey_target_clusters` (lista de clusters, uno por línea o multi-select en AAP). La lógica Hub-to-Spoke y la iteración por cluster están dentro del rol.

```bash
# Ejecutar todas las revisiones en uno o más clusters
ansible-playbook playbooks/inform.yaml \
  -i inventories/localhost.yml \
  -e "survey_target_clusters=cluster-acs\ncluster-2" \
  -e "report_name=ALL"

# Con push de reportes a GitLab (opcional)
ansible-playbook playbooks/inform.yaml \
  -i inventories/localhost.yml \
  -e "survey_target_clusters=cluster-acs" \
  -e "report_name=ALL" \
  -e "git_workdir=/tmp/compliance-reports-git" \
  -e "gitlab_repo_url=https://gitlab.com/mi-org/reportes" \
  -e "gitlab_token=tu_token" \
  -e "gitlab_user=ansible-bot"
```

#### Playbook Enforce (Aplicación de Controles de Seguridad)

```bash
# Aplicar controles en uno o más clusters (lista de clusters vía survey_target_clusters)
ansible-playbook playbooks/enforce.yaml \
  -i inventories/localhost.yml \
  -e "survey_target_clusters=cluster-acs\ncluster-2" \
  -e "enforce_list=ALL"

# Con push de reportes a GitLab (opcional)
ansible-playbook playbooks/enforce.yaml \
  -i inventories/localhost.yml \
  -e "survey_target_clusters=cluster-acs" \
  -e "enforce_list=ALL" \
  -e "git_workdir=/tmp/compliance-reports-git" \
  -e "gitlab_repo_url=https://gitlab.com/mi-org/reportes" \
  -e "gitlab_token=tu_token" \
  -e "gitlab_user=ansible-bot"
```

## Diagrama de Flujo

El siguiente diagrama muestra el flujo de ejecución del playbook `orchestrator_aap_multicluster.yml`:

```mermaid
flowchart TD
    Start([Inicio del Playbook]) --> Normalize[Normalizar Credenciales<br/>desde Environment Variables]
    Normalize --> Validate[Validar Variables<br/>Obligatorias]
    Validate --> NormalizeData[Normalizar Lista<br/>de Clusters]
    NormalizeData --> Debug[Mostrar Configuración<br/>Recibida]
    
    Debug --> CheckGitOps{do_gitops<br/>= true?}
    CheckGitOps -->|Sí| GitOps[Fase GitOps<br/>- Clonar Repo<br/>- Actualizar Políticas<br/>- Commit & Push]
    CheckGitOps -->|No| CheckExport
    GitOps --> CheckExport{do_export_html<br/>= true?}
    
    CheckExport -->|Sí| LoopStart[Iniciar Bucle<br/>por Cluster]
    CheckExport -->|No| CheckGitLab

    LoopStart --> ForEach[Para cada Cluster:<br/>- Obtener Kubeconfig<br/>- Buscar PVCs<br/>- Extraer Reportes<br/>- Generar HTML<br/>- Comprimir en ZIP]
    ForEach --> NextCluster{Hay más<br/>clusters?}
    NextCluster -->|Sí| ForEach
    NextCluster -->|No| CheckGitLab

    CheckGitLab{do_push_gitlab<br/>= true?}
    CheckGitLab -->|Sí| FindZips[Buscar todos los ZIPs<br/>generados]
    CheckGitLab -->|No| Summary
    FindZips --> BuildList[Construir Lista<br/>de Clusters Procesados]
    BuildList --> CloneRepo[Clonar Repo GitLab<br/>con OAuth2]
    CloneRepo --> CopyReports[Copiar ZIPs a repo<br/>reports/&lt;cluster&gt;/]
    CopyReports --> GitCommit[Git add, commit, push]
    GitCommit --> Summary
    
    Summary[Resumen Final<br/>de Ubicación de Reportes] --> End([Fin del Playbook])

    style Start fill:#90EE90
    style End fill:#FFB6C1
    style GitOps fill:#87CEEB
    style ForEach fill:#DDA0DD
    style GitCommit fill:#F0E68C
```

### Descripción de las Fases del Orquestador

1. **Normalización de Credenciales**: Lee credenciales desde Environment Variables de AAP (GitHub, GitLab) y las convierte en variables de Ansible
2. **Validación**: Verifica que todas las variables requeridas estén presentes según los flags activados (`do_gitops`, `do_export_html`, `do_push_gitlab`)
3. **Normalización de Datos**: Convierte la lista de clusters (`survey_target_clusters`) en formato estándar
4. **Fase GitOps** (opcional): Actualiza políticas de compliance en el repositorio GitOps
5. **Fase Extracción** (opcional): Por cada cluster, extrae reportes desde PVCs y genera HTML/ZIP
6. **Push a GitLab** (opcional): Clona el repo GitLab, copia los ZIPs a `reports/<nombre_cluster>/`, commit y push
7. **Resumen Final**: Muestra la ubicación de los reportes generados y el resultado del push

## Características Principales

### Playbooks de Controles de Seguridad

El proyecto incluye dos playbooks especializados para la gestión de controles de seguridad:

#### Playbook `inform.yaml`

Ejecuta revisiones y genera reportes sobre el estado de los controles de seguridad sin realizar cambios. Incluye:

- **Kubeadmin**: Verifica la existencia del usuario kubeadmin y si es seguro eliminarlo
- **Log Forwarder**: Revisa la configuración del log forwarder
- **Ingress TLS**: Verifica la configuración TLS en los recursos de ingress
- **LDAP TLS**: Revisa la configuración TLS en la integración LDAP
- **ACS Sensor**: Verifica el estado del sensor de Advanced Cluster Security
- **Network Policies**: Revisa las políticas de red configuradas
- **OAuth Timeouts**: Informa sobre la configuración actual de timeouts OAuth
- **Remediaciones Automáticas**: Lista las ComplianceRemediations detectadas por el Compliance Operator

**Variables principales:**
- `report_name`: Controla qué revisiones ejecutar (`ALL` para todas, o lista separada por comas: `kubeadmin,logs,ingress`)

#### Playbook `enforce.yaml`

Aplica cambios y configura controles de seguridad automáticamente. Incluye:

- **Remediaciones Automáticas**: Aplica ComplianceRemediations del Compliance Operator
- **OAuth Timeouts**: Configura timeouts de OAuth globales y por cliente
  - Timeout global: `10m0s` (accessTokenInactivityTimeout)
  - Timeout por cliente: `600s` (accessTokenInactivityTimeoutSeconds)

**Variables principales:**
- `enforce_list`: Controla qué controles aplicar (`ALL` para todos, o lista: `remediaciones_automaticas,oauth`)
- `remediation_name`: Filtro para remediaciones específicas (default: `ALL`)
- `oauth_client`: Filtro para clientes OAuth específicos (default: `ALL`)

### Multi-Cluster Support

El playbook `orchestrator_aap_multicluster.yml` procesa múltiples clusters en una sola ejecución:

- Procesa todos los clusters especificados en `survey_target_clusters` (texto, uno por línea, o multi-select en AAP)
- Genera reportes individuales por cluster
- Sube los ZIPs al repositorio GitLab en la ruta `reports/<nombre_cluster>/` (si `do_push_gitlab=true`)

Los playbooks `inform.yaml` y `enforce.yaml` también iteran sobre la lista de clusters: reciben `survey_target_clusters` (o `target_clusters_list`), y el rol ejecuta la lógica Hub-to-Spoke y las tareas por cada cluster. Los reportes se suben a GitLab en `reportes_controles_seguridad/<nombre_cluster>/inform/` o `.../enforce/` según el playbook.

### Entrega de Reportes (GitLab)

- **Orquestador**: Push de ZIPs de compliance (HTML + summary) al repo GitLab en `reports/<nombre_cluster>/` (un archivo ZIP por cluster) tras la exportación.
- **Inform/Enforce**: Push de reportes TXT al repo GitLab con la siguiente **nomenclatura de carpetas**:
  - `reportes_controles_seguridad/<nombre_cluster>/inform/` → reportes del playbook Inform
  - `reportes_controles_seguridad/<nombre_cluster>/enforce/` → reportes del playbook Enforce  
  Se mantienen solo los 5 archivos más recientes por carpeta (por cluster y tipo).
- Autenticación OAuth2 con token (URL `https://oauth2:TOKEN@...`).
- Variables: `gitlab_repo_url`, `gitlab_token`, `gitlab_user`, `git_workdir` (y opcionalmente `gitlab_repo_branch`).

### Seguridad

- **Sin valores hardcodeados**: Todas las variables sensibles se inyectan desde AAP
- **Validación de inputs**: El playbook valida que todas las variables requeridas estén presentes según los flags activados
- **Credenciales seguras**: Soporte para Source Control Credentials, OpenShift/Kubernetes (Hub ACM) y Environment Variables en AAP
- **Conexión Hub-to-Spoke**: Los roles Inform y Enforce obtienen el kubeconfig del spoke desde el Hub con `kubernetes.core.k8s_info` (secret `admin-kubeconfig` en el namespace del cluster), fuerzan su uso en un bloque con `environment` (KUBECONFIG + K8S_AUTH_* vacíos) para que todas las consultas vayan al spoke y no al Hub, y borran el archivo temporal al finalizar

### 100% Agnóstico

- No contiene valores hardcodeados de usuarios, tokens o contraseñas
- Todas las variables se inyectan desde AAP (Extra Vars, Survey, Credentials)
- Fácil de adaptar a diferentes entornos

### Estándares de Compliance Soportados

El rol `compliance_export_html` procesa únicamente los siguientes estándares de compliance:

#### Estándares PCI-DSS
- **`ocp4-pci-dss-4-0`**: Estándar PCI-DSS 4.0 para plataforma
- **`ocp4-pci-dss-node-4-0-*`**: Estándar PCI-DSS 4.0 para nodos (incluye variantes con sufijos como `-master`, `-worker`, etc.)

#### Estándares CIS
- **`ocp4-cis-1-7`**: Estándar CIS 1.7 para plataforma
- **`ocp4-cis-node-1-7-*`**: Estándar CIS 1.7 para nodos (incluye variantes con sufijos como `-master`, `-worker`, etc.)

**Nota**: El filtro utiliza coincidencias exactas para los estándares de plataforma y coincidencias por prefijo para los estándares de nodos, permitiendo capturar automáticamente todas las variantes con sufijos de nodos (ej: `ocp4-cis-node-1-7-master`, `ocp4-cis-node-1-7-worker`, `ocp4-pci-dss-node-4-0-master`, etc.).

Los PVCs que no coincidan con estos estándares serán ignorados durante el procesamiento.

## Roles de Controles de Seguridad

### Rol `controles-seguridad-inform`

Este rol realiza revisiones y auditorías de controles de seguridad sin realizar cambios en el cluster. Genera reportes detallados sobre el estado actual de la configuración.

#### Tareas de Revisión

1. **01_kubeadmin.yml**: Verifica la existencia del usuario kubeadmin y evalúa si es seguro eliminarlo basándose en la presencia de identity providers configurados.

2. **02_log_forwarder.yml**: Revisa la configuración del log forwarder y su estado operativo.

3. **03_ingress_tls.yml**: Verifica la configuración TLS en los recursos de ingress del cluster.

4. **04_ldap_tls.yml**: Revisa la configuración TLS en la integración LDAP/Active Directory.

5. **05_acs_sensor.yml**: Verifica el estado del sensor de Advanced Cluster Security (ACS/StackRox).

6. **06_network_policies.yml**: Revisa las políticas de red configuradas y genera un reporte de cobertura.

7. **07_oauth_timeouts_inform.yml**: Informa sobre la configuración actual de timeouts OAuth (global y por cliente).

8. **automatic_remediation_inform.yml**: Lista todas las ComplianceRemediations detectadas por el Compliance Operator y su estado actual.

9. **99_send_report.yml**: Genera un reporte consolidado (TXT) y, si están definidas las variables GitLab (`git_workdir`, `gitlab_repo_url`, `gitlab_token`), lo sube al repositorio GitLab en `reportes_controles_seguridad/<nombre_cluster>/inform/`; se mantienen solo los 5 archivos más recientes por carpeta.

#### Control de Ejecución

- **Entrada**: El rol itera sobre `target_clusters_list` (derivada de `survey_target_clusters` en los playbooks). Por cada cluster ejecuta `process_cluster.yml` con `target_cluster_name` definido.
- **Conexión Hub-to-Spoke**: Obtiene el secret `admin-kubeconfig` del Hub con `kubernetes.core.k8s_info` (credencial del Job Template), decodifica el kubeconfig y lo guarda en `/tmp/kubeconfig-<cluster>`. Todas las tareas siguientes se ejecutan dentro de un bloque con `environment` que fuerza `KUBECONFIG` a ese archivo y anula `K8S_AUTH_*`, de modo que las consultas van al spoke y no al Hub. Al final se borra el archivo temporal.
- **report_name**: `ALL` ejecuta todas las revisiones; lista específica ejecuta solo las indicadas (ej: `kubeadmin,logs,ingress`).

### Rol `controles-seguridad-enforce`

Este rol aplica cambios y configura controles de seguridad automáticamente en cada cluster. La iteración por cluster y la conexión Hub-to-Spoke son iguales que en Inform.

#### Tareas de Aplicación

1. **remediaciones_automaticas_enforce.yaml**: 
   - Obtiene todas las ComplianceRemediations del Compliance Operator
   - Aplica las remediaciones configurando `spec.apply: true`
   - Genera un reporte con el estado de aplicación
   - Soporta filtrado por nombre de remediación mediante la variable `remediation_name`

2. **071_oauth_timeouts_enforce.yml**:
   - Configura el timeout global de OAuth a `10m0s` (accessTokenInactivityTimeout)
   - Configura timeouts por cliente OAuth a `600s` (accessTokenInactivityTimeoutSeconds)
   - Genera un respaldo de la configuración original antes de aplicar cambios
   - Soporta filtrado de clientes mediante la variable `oauth_client`

3. **99_send_report.yml**: Genera un reporte consolidado (TXT) y, si están definidas las variables GitLab, lo sube al repositorio GitLab en `reportes_controles_seguridad/<nombre_cluster>/enforce/` (retención de 5 archivos más recientes por carpeta).

#### Control de Ejecución

Las tareas se ejecutan condicionalmente basándose en la variable `enforce_list`:
- `ALL`: Aplica todos los controles
- Lista específica: Aplica solo los controles especificados (ej: `remediaciones_automaticas,oauth`)

#### Seguridad y Respaldo

- El rol genera respaldos de la configuración original antes de aplicar cambios
- Los respaldos se incluyen en el reporte final para facilitar la reversión si es necesario
- Las acciones se registran detalladamente en el reporte

## Variables Principales

### Flags de Control

| Variable | Tipo | Descripción | Default |
|----------|------|-------------|---------|
| `do_gitops` | boolean | Activar actualización de políticas GitOps | `false` |
| `do_export_html` | boolean | Activar exportación de reportes HTML | `false` |
| `do_push_gitlab` | boolean | Activar push de reportes al repositorio GitLab | `false` |

### Variables de GitOps (Requeridas si `do_gitops=true`)

| Variable | Tipo | Descripción | Default |
|----------|------|-------------|---------|
| `github_user` | string | Usuario de GitHub | - |
| `github_token` | string | Token de GitHub (🔒 Credential) | - |
| `gitops_repo_branch` | string | Branch del repositorio GitOps | `main` |
| `run_cis` | boolean | Habilitar escaneo CIS | `true` |
| `run_pci` | boolean | Habilitar escaneo PCI-DSS | `false` |
| `scan_remediation_action` | string | Acción de remediación (`inform`, `enforce`) | `inform` |
| `scan_schedule` | string | Schedule cron para escaneos | `"0 1 * * *"` |
| `scan_setting_name` | string | Nombre del ScanSetting | `periodic-daily` |
| `placement_label_key` | string | Key del label para placement | `compliance` |
| `placement_label_value` | string | Valor del label para placement | `enabled` |

### Variables de GitLab (Orquestador; requeridas si `do_push_gitlab=true`)

| Variable | Tipo | Descripción | Default |
|----------|------|-------------|---------|
| `gitlab_repo_url` | string | URL HTTPS del repositorio GitLab | - |
| `gitlab_token` | string | Token de acceso GitLab (🔒 Credential) | - |
| `gitlab_user` | string | Usuario Git para commits | - |
| `git_workdir` | string | Directorio temporal para clonar el repo | `/tmp/compliance-reports-git` |
| `gitlab_repo_branch` | string | Rama del repositorio | `main` |
| `gitlab_commit_message` | string | Mensaje del commit (opcional) | Mensaje por defecto con clusters y fecha |

El orquestador acepta también `GITLAB_TOKEN` y `GITLAB_USER` desde Environment Variables (inyección desde credencial en AAP).

### Variables de Multi-Cluster / Conexión Hub

| Variable | Tipo | Descripción | Default |
|----------|------|-------------|---------|
| `survey_target_clusters` | string/list | Lista de clusters a procesar | - |
| `hub_kubeconfig_path` | string | Ruta al archivo kubeconfig del Hub (opcional). Si no se define, se usa la variable de entorno `KUBECONFIG` inyectada por la credencial OpenShift/Kubernetes en AAP. Útil cuando la credencial no inyecta KUBECONFIG en el job. | `""` |

### Variables de Controles de Seguridad - Inform

| Variable | Tipo | Descripción | Default |
|----------|------|-------------|---------|
| `survey_target_clusters` | string/list | Lista de clusters a procesar (uno por línea, multi-select en AAP, o lista). Los playbooks la convierten en `target_clusters_list`. | - |
| `report_name` | string | Controles a revisar (`ALL` o lista: `kubeadmin,logs,ingress,ldap,acs,network,oauth,remediation`) | `ALL` |
| `report_dir` | string | Directorio local para guardar reportes TXT | `/tmp/ocp-reports` |
| `report_file` | string | Nombre base del archivo de reporte | `reporte-seguridad-<fecha>` |
| `system_ns_regex` | string | Expresión regular para filtrar namespaces del sistema en network policies | `^(openshift.*\|kube.*\|default\|stackrox)$` |
| **GitLab (opcional)** | | Para subir reportes al repo | |
| `git_workdir` | string | Directorio temporal para clonar el repo GitLab | - |
| `gitlab_repo_url` | string | URL HTTPS del repositorio GitLab | - |
| `gitlab_token` | string | Token de acceso GitLab (🔒 Credential) | - |
| `gitlab_user` | string | Usuario Git para commits | - |
| `gitlab_repo_branch` | string | Rama del repositorio | `main` |

**Nota**: La conexión a cada cluster es Hub-to-Spoke: el rol obtiene el kubeconfig del spoke desde el Hub (secret `admin-kubeconfig`) con la credencial OpenShift/Kubernetes del Job Template y fuerza su uso en las tareas contra el spoke. Se requiere credencial del Hub ACM en AAP.

### Variables de Controles de Seguridad - Enforce

| Variable | Tipo | Descripción | Default |
|----------|------|-------------|---------|
| `survey_target_clusters` | string/list | Lista de clusters a procesar (igual que Inform) | - |
| `enforce_list` | string | Controles a aplicar (`ALL` o lista: `remediaciones_automaticas,oauth`) | `ALL` |
| `remediation_name` | string | Filtro de remediaciones (`ALL` o lista separada por comas) | `ALL` |
| `oauth_client` | string | Filtro de clientes OAuth (`ALL` o lista separada por comas) | `ALL` |
| `report_dir` | string | Directorio local para guardar reportes | `/tmp/ocp-reports` |
| **GitLab (opcional)** | | Para subir reportes al repo (mismas variables que Inform) | - |

**Estructura de reportes en el repo GitLab (Inform/Enforce):**
```
reportes_controles_seguridad/
  <nombre_cluster>/          # ej. cluster-2, cluster-acs
    inform/                  # reportes del playbook Inform
      reporte-seguridad-....txt
    enforce/                 # reportes del playbook Enforce
      reporte-seguridad-....txt
```

**🔒 SEGURIDAD**: Las variables marcadas con 🔒 deben configurarse como **Credentials** o **Environment Variables** en AAP (nunca en texto plano).

## Troubleshooting

### Error: "Faltan variables de Git"

**Solución**: Verificar que `github_user`, `github_token` y `gitops_repo_branch` estén definidas cuando `do_gitops=true`.

### Error: "Faltan variables de GitLab"

**Solución**: Verificar que `gitlab_repo_url`, `gitlab_token`, `gitlab_user` y `git_workdir` estén definidas cuando `do_push_gitlab=true` (orquestador) o cuando quieras subir reportes desde Inform/Enforce.

### Error: "Faltan variables de Git" (Hub-to-Spoke)

**Solución**: Los roles Inform y Enforce usan **`kubernetes.core.k8s_info`** para leer el secret `admin-kubeconfig` en el Hub; utilizan la **credencial OpenShift/Kubernetes** que asocias al Job Template (la misma que ves en "Credentials"). No se usa el CLI `oc`, así que funciona con credenciales tipo **Bearer Token** o **Kubeconfig**.
1. Asocia la credencial del **Hub ACM** (OpenShift/Kubernetes) al Job Template de Inform y Enforce.
2. Asegúrate de que `survey_target_clusters` (o `target_clusters_list`) contenga los nombres de los clusters que coinciden con los **namespaces** de los managed clusters en el Hub (p. ej. `cluster-2`).
3. Si aun así falla, revisa que el secret `admin-kubeconfig` exista en el namespace de cada cluster en el Hub: `oc get secret admin-kubeconfig -n <nombre-cluster>` (desde una sesión donde tengas acceso al Hub).

### No se encuentran PVCs en los clusters

**Solución**: 
1. Verificar que el Compliance Operator esté instalado
2. Verificar que se hayan ejecutado escaneos previamente
3. Verificar que los PVCs existan en el namespace `openshift-compliance`
4. **Verificar que los PVCs coincidan con los estándares soportados**: El playbook solo procesa PVCs que coincidan con los siguientes estándares:
   - `ocp4-pci-dss-4-0`
   - `ocp4-pci-dss-node-4-0-*` (ej: `ocp4-pci-dss-node-4-0-master`, `ocp4-pci-dss-node-4-0-worker`)
   - `ocp4-cis-1-7`
   - `ocp4-cis-node-1-7-*` (ej: `ocp4-cis-node-1-7-master`, `ocp4-cis-node-1-7-worker`)
   
   Si tus PVCs tienen nombres diferentes, no serán procesados. Verifica los nombres de tus PVCs con:
   ```bash
   oc get pvc -n openshift-compliance
   ```

---

## Consideraciones de cara al futuro

Recomendaciones para el cliente a partir del flujo actual de los playbooks, las variables utilizadas y la integración con AAP y GitLab.

### Variables y configuración

- **Centralizar variables en AAP**: Usar un único inventario o conjunto de Extra Variables (por Job Template o por proyecto) para `git_workdir`, `gitlab_repo_url`, `gitlab_repo_branch`, etc., y evitar duplicar valores entre el orquestador, Inform y Enforce.
- **Catálogo de variables**: Mantener un documento interno (o ampliar esta guía) con todas las variables, si son obligatorias u opcionales, y valores recomendados por entorno (desarrollo, staging, producción).
- **Survey**: Mantener `survey_target_clusters` con la misma convención que los **namespaces** de los managed clusters en el Hub (ACM); documentar la lista de nombres válidos para reducir errores de “kubeconfig no encontrado”.

### Seguridad

- **Tokens GitLab**: Usar tokens con permisos mínimos (p. ej. solo `write_repository` para el repo de reportes). Establecer una política de **rotación periódica** y actualizar la credencial en AAP.
- **Credencial del Hub**: La credencial OpenShift/Kubernetes del Hub debe tener solo el alcance necesario (lectura de secrets en los namespaces de los managed clusters). Evitar reutilizar la misma credencial para otros fines si es posible segregar.
- **Repo de reportes**: Valorar ramas protegidas o permisos de escritura limitados al servicio/bot que hace push, para que el contenido del repo sea solo el generado por la automatización.

### Escalabilidad y rendimiento

- **Muchos clusters**: Los playbooks iteran por cluster en **secuencia**. Si el número de clusters crece mucho, valorar ejecutar varios Job Templates en paralelo (p. ej. particionando la lista de clusters) o revisar opciones de AAP para paralelismo.
- **Retención de reportes**: La retención de **5 archivos** por carpeta (`inform/`, `enforce/` por cluster) está fija en el código. Si se necesita más o menos historial, conviene parametrizarlo como variable (p. ej. `report_retention_count`) en los roles.
- **Tamaño del repo GitLab**: Si se acumulan muchos ZIPs en `reports/<cluster>/` (orquestador) o muchos TXT en `reportes_controles_seguridad/`, definir una política de archivado o limpieza (p. ej. borrar o mover reportes antiguos) para no inflar el repo.

### Operación y mantenimiento

- **Monitoreo**: Configurar alertas en AAP ante fallos de job (push a GitLab, extracción de kubeconfig, errores de módulos `kubernetes.core`). Revisar periódicamente que los reportes lleguen al repo en la estructura esperada.
- **Execution Environment**: Mantener el EE actualizado (colecciones Ansible, `oc`, dependencias) y probar los playbooks tras actualizaciones de AAP o del EE.
- **Nombres de clusters**: Cualquier cambio en los nombres de managed clusters en ACM debe reflejarse en `survey_target_clusters` (o en la fuente que alimente esa variable) para que la extracción del kubeconfig siga funcionando.

### Evolución del producto

- **Nuevos controles (Inform/Enforce)**: Añadir nuevas revisiones o remediaciones siguiendo el patrón actual: nuevo archivo de tareas (p. ej. `08_nuevo_control.yml`), incluido desde `process_cluster.yml`, y actualización de `report_name` o `enforce_list` en defaults y documentación.
- **Nuevos estándares de compliance**: Si se incorporan estándares distintos a CIS 1.7 y PCI-DSS 4.0, actualizar los filtros de PVCs en el rol `compliance_export_html` (y, si aplica, la documentación de estándares soportados).
- **Compatibilidad con AAP**: En cada upgrade mayor de AAP, comprobar que las credenciales (OpenShift/Kubernetes, GitLab) y los Job Templates sigan funcionando y que no cambie el comportamiento de inyección de variables (p. ej. `K8S_AUTH_*`, `KUBECONFIG`).

### Repositorio GitLab

- **Rama por defecto**: Dejar alineado `gitlab_repo_branch` con la rama por defecto del repo (p. ej. `main` o `master`) para evitar confusiones y conflictos.
- **Estructura de carpetas**: No eliminar manualmente las carpetas `reportes_controles_seguridad/` ni `reports/` si los jobs las recrean o escriben en ellas; en caso de reestructuración del repo, actualizar las rutas en los roles (`cluster_report_dir`, rutas del orquestador) y la documentación.

### Documentación y formación

- **Runbooks**: Tener procedimientos cortos para errores frecuentes (kubeconfig no encontrado, push fallido, variable indefinida, PVCs no encontrados), enlazando con la sección Troubleshooting de este README.
- **Guía de AAP**: Mantener `playbooks/GUIA_ACTUALIZACION_AAP_GITLAB.md` actualizada cuando se añadan variables, credenciales o pasos en los Job Templates.
- **Trazabilidad**: Los mensajes de commit en GitLab incluyen tipo de reporte (Inform/Enforce), nombre de cluster y fecha; usar ese historial para auditoría y resolución de incidencias.
