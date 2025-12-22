# Cómo Ejecutar el Playbook

## Método Recomendado: Usar el Script Wrapper

El script `ejecutar-playbook-hub.sh` configura automáticamente todas las variables de entorno necesarias:

```bash
./scripts/ejecutar-playbook-hub.sh -e "do_gitops=true do_export_html=true github_token=TU_TOKEN"
```

## Método Alternativo: Ejecutar Directamente con ansible-playbook

Si prefieres ejecutar `ansible-playbook` directamente, debes exportar `ANSIBLE_ROLES_PATH` primero:

```bash
export ANSIBLE_ROLES_PATH="$(pwd)/roles"
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "do_gitops=true do_export_html=true github_token=TU_TOKEN"
```

O en una sola línea:

```bash
ANSIBLE_ROLES_PATH="$(pwd)/roles" ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "do_gitops=true do_export_html=true github_token=TU_TOKEN"
```

## Ejemplos de Uso

### 1. Solo GitOps (aplica a todos los clusters con compliance=enabled)
```bash
./scripts/ejecutar-playbook-hub.sh -e "do_gitops=true do_export_html=false github_token=TU_TOKEN"
```

### 2. Solo Export HTML de clusters específicos
```bash
./scripts/ejecutar-playbook-hub.sh cluster-acs cluster-2 -e "do_gitops=false do_export_html=true"
```

### 3. Ambos (GitOps + Export HTML) en clusters específicos
```bash
./scripts/ejecutar-playbook-hub.sh cluster-acs cluster-2 -e "do_gitops=true do_export_html=true github_token=TU_TOKEN"
```

### 4. Ambos usando clusters por defecto (cluster-acs cluster-2)
```bash
./scripts/ejecutar-playbook-hub.sh -e "do_gitops=true do_export_html=true github_token=TU_TOKEN"
```

## Nota Importante

El script `ejecutar-playbook-hub.sh` configura automáticamente:
- `ANSIBLE_ROLES_PATH` apuntando a `./roles`
- Manejo correcto de argumentos de Ansible
- Iteración sobre múltiples clusters si se especifican
- Organización de reportes por cluster

Por lo tanto, **se recomienda usar siempre el script wrapper** en lugar de ejecutar `ansible-playbook` directamente.

