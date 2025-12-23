# Cómo Ejecutar el Playbook

## Configuración de Correo Electrónico

El playbook puede enviar automáticamente los reportes de compliance por correo electrónico. Esto es especialmente útil cuando se ejecuta en **AAP (Automated Ansible Platform)** donde los Pods son efímeros y los archivos se pierden al finalizar.

> 📖 **Para configuración detallada en AAP, consulta**: [CONFIGURACION-EMAIL-AAP.md](CONFIGURACION-EMAIL-AAP.md)

### Configuración SMTP

**Para Gmail:**
1. Habilitar "Verificación en 2 pasos" en tu cuenta de Google
2. Generar una "Contraseña de aplicación" desde: https://myaccount.google.com/apppasswords
3. Usar esa contraseña como `email_smtp_password`

**Para Outlook/Office 365:**
- Usar `smtp.office365.com` como host
- Usar tu correo corporativo como username
- Usar tu contraseña normal o una contraseña de aplicación

**Variables requeridas:**
- `email_smtp_host`: Servidor SMTP (ej: `smtp.gmail.com`, `smtp.office365.com`)
- `email_smtp_port`: Puerto SMTP (generalmente `587` para STARTTLS)
- `email_smtp_username`: Usuario SMTP
- `email_smtp_password`: Contraseña SMTP
- `email_to`: Destinatario del correo
- `email_from`: Remitente (opcional, usa `email_smtp_username` por defecto)

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

### 5. Export HTML + Envío por correo electrónico
```bash
./scripts/ejecutar-playbook-hub.sh cluster-acs cluster-2 \
  -e "do_export_html=true" \
  -e "do_send_email=true" \
  -e "email_smtp_host=smtp.gmail.com" \
  -e "email_smtp_port=587" \
  -e "email_smtp_username=tu_email@gmail.com" \
  -e "email_smtp_password=tu_app_password" \
  -e "email_to=destinatario@banorte.com" \
  -e "email_from=tu_email@gmail.com"
```

### 6. Pipeline completo (GitOps + Export HTML + Email)
```bash
./scripts/ejecutar-playbook-hub.sh cluster-acs cluster-2 \
  -e "do_gitops=true" \
  -e "do_export_html=true" \
  -e "do_send_email=true" \
  -e "github_token=TU_TOKEN" \
  -e "email_smtp_host=smtp.gmail.com" \
  -e "email_smtp_port=587" \
  -e "email_smtp_username=tu_email@gmail.com" \
  -e "email_smtp_password=tu_app_password" \
  -e "email_to=destinatario@banorte.com"
```

## Nota Importante

El script `ejecutar-playbook-hub.sh` configura automáticamente:
- `ANSIBLE_ROLES_PATH` apuntando a `./roles`
- Manejo correcto de argumentos de Ansible
- Iteración sobre múltiples clusters si se especifican
- Organización de reportes por cluster

Por lo tanto, **se recomienda usar siempre el script wrapper** en lugar de ejecutar `ansible-playbook` directamente.

