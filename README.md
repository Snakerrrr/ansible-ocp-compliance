# Ansible OpenShift Compliance Automation

Automatización de compliance para OpenShift usando Ansible, el Compliance Operator de OpenShift y GitOps con ACM (Advanced Cluster Management).

## Descripción

Este proyecto automatiza la gestión de compliance en entornos OpenShift multi-cluster mediante:

- **GitOps**: Configuración declarativa de políticas de compliance usando PolicyGenerator de ACM
- **Compliance Operator**: Escaneos automáticos y periódicos de compliance (CIS, PCI-DSS)
- **Exportación de Reportes**: Generación de reportes HTML desde los resultados de compliance
- **Multi-cluster**: Soporte para ejecución en múltiples clusters gestionados desde un Hub

## Estructura del Proyecto

```
.
├── playbooks/              # Playbooks principales
│   ├── compliance-pipeline.yml          # Playbook principal del pipeline
│   └── orchestrator_aap_multicluster.yml # Orquestador para ejecución en AAP
├── roles/                  # Roles de Ansible
│   ├── gitops_policy_update    # Actualización de políticas GitOps
│   ├── toggle_policies         # Generación de configuraciones
│   ├── compliance_wait         # Espera de instalación del operador
│   └── compliance_export_html  # Exportación de reportes HTML
├── scripts/                # Scripts de utilidad
│   ├── ejecutar-playbook-hub.sh  # Script principal de ejecución
│   └── commit-and-push.sh        # Helper para GitOps
└── inventories/            # Inventarios de Ansible
```

## Requisitos

- Ansible 2.9+
- OpenShift CLI (`oc`)
- Acceso a un Hub cluster de ACM (Advanced Cluster Management)
- Credenciales configuradas en AAP (Automated Ansible Platform) o kubeconfig local
- Repositorio GitOps configurado

## Uso Rápido

### Ejecución desde línea de comandos

```bash
# Ejecutar solo GitOps (actualizar políticas)
./scripts/ejecutar-playbook-hub.sh -e "do_gitops=true"

# Ejecutar solo export HTML (generar reportes)
./scripts/ejecutar-playbook-hub.sh cluster-acs cluster-2 -e "do_export_html=true"

# Ejecutar ambos (GitOps + Export HTML)
./scripts/ejecutar-playbook-hub.sh cluster-acs cluster-2 \
  -e "do_gitops=true" \
  -e "do_export_html=true"
```

### Ejecución directa con ansible-playbook

```bash
export ANSIBLE_ROLES_PATH=$(pwd)/roles

ansible-playbook playbooks/compliance-pipeline.yml \
  -e "do_gitops=true" \
  -e "do_export_html=true" \
  -e "target_cluster_context=cluster-acs"
```

## Documentación

- **[EJECUTAR-PLAYBOOK.md](EJECUTAR-PLAYBOOK.md)**: Guía detallada de ejecución
- **[CONFIGURACION-PLACEMENT-MULTICLUSTER.md](CONFIGURACION-PLACEMENT-MULTICLUSTER.md)**: Configuración de placement para multi-cluster
- **[CONFIGURACION-SCAN-SETTING.md](CONFIGURACION-SCAN-SETTING.md)**: Configuración de escaneos periódicos

## Variables Principales

| Variable | Descripción | Default |
|----------|-------------|---------|
| `do_gitops` | Activar actualización de políticas GitOps | `false` |
| `do_export_html` | Activar exportación de reportes HTML | `false` |
| `target_cluster_context` | Contexto del cluster objetivo | `''` (Hub) |
| `cis_scan_enabled` | Habilitar escaneo CIS | `true` |
| `pci_scan_enabled` | Habilitar escaneo PCI-DSS | `false` |
| `scan_schedule` | Schedule cron para escaneos | `"0 2 * * *"` |
| `placement_label_key` | Key del label para placement | `compliance` |
| `placement_label_value` | Valor del label para placement | `enabled` |

## Licencia

Apache License 2.0
