# Configuración de Envío de Correo en AAP

Esta guía explica cómo configurar el envío automático de reportes de compliance por correo electrónico cuando se ejecuta el playbook en **Ansible Automation Platform (AAP)**.

## ¿Por qué es necesario?

En AAP, los trabajos se ejecutan en **Pods efímeros** de Kubernetes/OpenShift:

1. El playbook genera los reportes en `/tmp/compliance-reports`
2. El trabajo termina
3. El Pod se destruye inmediatamente
4. **Los reportes se pierden para siempre** ❌

**Solución**: Enviar los reportes por correo **antes** de que el Pod termine.

## Configuración en AAP

### Opción 1: Variables de Entorno (Recomendado para Passwords)

Las credenciales sensibles (como passwords) deben configurarse como **Variables de Entorno** en el Job Template de AAP.

#### Pasos:

1. En AAP, ve a tu **Job Template**
2. Ve a la sección **Variables de Entorno**
3. Agrega las siguientes variables:

```yaml
EMAIL_SMTP_HOST: smtp.gmail.com
EMAIL_SMTP_PORT: 587
EMAIL_SMTP_USERNAME: tu_email@gmail.com
EMAIL_SMTP_PASSWORD: tu_app_password
EMAIL_TO: destinatario@banorte.com
EMAIL_FROM: tu_email@gmail.com  # Opcional
```

**Ventajas:**
- Las passwords no aparecen en los logs
- Se pueden rotar fácilmente
- Mejor práctica de seguridad

### Opción 2: Extra Variables

Puedes pasar las variables directamente como **Extra Variables** en el Job Template:

```yaml
do_export_html: true
do_send_email: true
email_smtp_host: smtp.gmail.com
email_smtp_port: 587
email_smtp_username: tu_email@gmail.com
email_smtp_password: tu_app_password
email_to: destinatario@banorte.com
```

**⚠️ Advertencia**: Las passwords en Extra Variables aparecen en los logs. **No recomendado para producción**.

### Opción 3: Secrets de AAP (Más Seguro)

Para máxima seguridad, usa **Secrets** de AAP:

1. En AAP, crea un **Credential** de tipo "Machine" o "Custom"
2. Almacena las credenciales SMTP allí
3. Referencia el credential en tu Job Template
4. El playbook puede acceder a ellas vía `lookup('env', 'VARIABLE_NAME')`

## Configuración SMTP

### Gmail

1. **Habilitar Verificación en 2 pasos**:
   - Ve a: https://myaccount.google.com/security
   - Activa "Verificación en 2 pasos"

2. **Generar Contraseña de Aplicación**:
   - Ve a: https://myaccount.google.com/apppasswords
   - Genera una contraseña para "Correo"
   - Usa esa contraseña (16 caracteres) como `EMAIL_SMTP_PASSWORD`

3. **Configuración**:
   ```yaml
   EMAIL_SMTP_HOST: smtp.gmail.com
   EMAIL_SMTP_PORT: 587
   EMAIL_SMTP_USERNAME: tu_email@gmail.com
   EMAIL_SMTP_PASSWORD: xxxx xxxx xxxx xxxx  # Contraseña de aplicación
   ```

### Outlook / Office 365

```yaml
EMAIL_SMTP_HOST: smtp.office365.com
EMAIL_SMTP_PORT: 587
EMAIL_SMTP_USERNAME: tu_email@banorte.com
EMAIL_SMTP_PASSWORD: tu_contraseña_normal
EMAIL_TO: destinatario@banorte.com
```

### Servidor SMTP Corporativo

```yaml
EMAIL_SMTP_HOST: smtp.corporativo.com
EMAIL_SMTP_PORT: 587  # o 465 para SSL
EMAIL_SMTP_USERNAME: usuario@corporativo.com
EMAIL_SMTP_PASSWORD: contraseña
EMAIL_TO: destinatario@corporativo.com
```

## Verificación del Execution Environment

El módulo `mail` de Ansible requiere las librerías Python:
- `smtplib` (incluida en Python estándar)
- `email` (incluida en Python estándar)

El Execution Environment basado en `quay.io/ansible/awx-ee:latest` **debería** tener estas librerías por defecto.

### Verificar Disponibilidad

El playbook verifica automáticamente si el módulo mail está disponible. Si no está disponible, verás una advertencia y el envío se omitirá.

### Si el módulo no está disponible

Si necesitas agregar dependencias adicionales, edita `ee-compliance/execution-environment.yml`:

```yaml
additional_build_steps:
  append_final:
    - RUN pip install secure-smtplib  # Si necesitas librerías adicionales
```

Luego reconstruye el Execution Environment.

## Ejemplo de Job Template en AAP

### Extra Variables del Job Template:

```yaml
do_export_html: true
do_send_email: true
target_cluster_context: cluster-acs
```

### Variables de Entorno del Job Template:

```yaml
EMAIL_SMTP_HOST: smtp.gmail.com
EMAIL_SMTP_PORT: 587
EMAIL_SMTP_USERNAME: compliance@banorte.com
EMAIL_SMTP_PASSWORD: "xxxx xxxx xxxx xxxx"
EMAIL_TO: bastian@banorte.com
EMAIL_FROM: compliance@banorte.com
```

## Ejecución Multi-Cluster

Cuando ejecutas el playbook `orchestrator_aap_multicluster.yml` para múltiples clusters, se enviará **un solo correo consolidado** con todos los reportes:

```yaml
# Extra Variables
do_export_html: true
do_send_email: true
survey_target_clusters: "cluster-acs,cluster-2"

# El playbook procesará todos los clusters y enviará UN correo al final
# con todos los ZIPs consolidados
```

El correo consolidado incluirá:
- **Un solo correo** con todos los clusters procesados
- **Múltiples archivos ZIP adjuntos** (uno por cluster)
- **Resumen de procesamiento** con lista de clusters
- **Detalle de archivos** con tamaño de cada ZIP
- **Soporte para múltiples destinatarios** (separados por comas)

### Ejemplo de Correo Consolidado

```
Asunto: Reporte de compliance multicluster - Reportes Multi-Cluster (2 clusters)

Cuerpo:
📊 RESUMEN DE PROCESAMIENTO
==========================
Total de clusters procesados: 2
Clusters: cluster-acs, cluster-2

📦 DETALLE DE ARCHIVOS ADJUNTOS
===============================
• Cluster: cluster-acs
  - Archivo: compliance_reports_cluster-acs_1767621683.zip
  - Tamaño: 3.2 MB
• Cluster: cluster-2
  - Archivo: compliance_reports_cluster-2_1767621683.zip
  - Tamaño: 3.2 MB

Adjuntos:
- compliance_reports_cluster-acs_1767621683.zip
- compliance_reports_cluster-2_1767621683.zip
```

## Troubleshooting

### Error: "Module mail not found"

**Causa**: El módulo mail no está disponible en el Execution Environment.

**Solución**: 
1. Verifica que estés usando un Execution Environment basado en `awx-ee:latest`
2. Reconstruye el Execution Environment si es necesario

### Error: "Authentication failed"

**Causa**: Credenciales SMTP incorrectas.

**Solución**:
- Para Gmail: Usa una **Contraseña de Aplicación**, no tu contraseña normal
- Verifica que el usuario y password sean correctos
- Verifica que el servidor SMTP sea accesible desde AAP

### Error: "Connection timeout" o "TimeoutError: The read operation timed out"

**Causa**: 
1. El servidor SMTP no es accesible desde AAP o el puerto está bloqueado
2. **O** el servidor SMTP procesó el correo correctamente pero cerró la conexión antes de confirmar (común con archivos grandes)

**Solución**:
- Verifica conectividad de red desde AAP al servidor SMTP
- Verifica que el firewall permita el puerto SMTP (587 o 465)
- Prueba con `telnet smtp.gmail.com 587` desde un Pod en AAP
- **Para archivos grandes**: Aumenta `email_smtp_timeout` a 90 o 120 segundos:
  ```yaml
  email_smtp_timeout: 90  # En Extra Variables
  ```
- **Nota importante**: Si el error es "TimeoutError" pero el correo se envió correctamente, el playbook maneja esto automáticamente con `ignore_errors: true` y muestra un mensaje informativo

### Los reportes no se envían pero el playbook termina exitosamente

**Causa**: El módulo mail no está disponible o las credenciales no están configuradas.

**Solución**:
1. Revisa los logs del job en AAP
2. Busca la advertencia "El módulo mail no está disponible"
3. Verifica que `do_send_email=true` esté configurado
4. Verifica que todas las variables de correo estén definidas

## Mejores Prácticas

1. **Usa Variables de Entorno para passwords**: No pongas passwords en Extra Variables
2. **Usa Contraseñas de Aplicación para Gmail**: Más seguras que contraseñas normales
3. **Configura EMAIL_FROM**: Usa un correo corporativo como remitente
4. **Prueba primero con un cluster**: Antes de ejecutar en producción
5. **Revisa los logs**: Si el envío falla, los logs mostrarán el error específico

## Ejemplo Completo

### Job Template en AAP:

**Nombre**: `Compliance Pipeline - Export + Email`

**Playbook**: `playbooks/orchestrator_aap_multicluster.yml` (para multi-cluster) o `playbooks/compliance-pipeline.yml` (para single cluster)

**Inventory**: `localhost`

**Extra Variables**:
```yaml
do_export_html: true
do_send_email: true
target_cluster_context: "{{ cluster_name }}"  # Variable de AAP
```

**Variables de Entorno**:
```yaml
EMAIL_SMTP_HOST: smtp.gmail.com
EMAIL_SMTP_PORT: 587
EMAIL_SMTP_USERNAME: compliance-automation@banorte.com
EMAIL_SMTP_PASSWORD: "xxxx xxxx xxxx xxxx"
EMAIL_TO: bastian@banorte.com,auditor@banorte.com  # Múltiples destinatarios separados por comas
EMAIL_FROM: compliance-automation@banorte.com
EMAIL_SMTP_TIMEOUT: 90  # Opcional: aumentar para archivos grandes
```

**Execution Environment**: `ee-compliance` (tu EE personalizado)

**Schedule**: Diario a las 3:00 AM (después de que los escaneos terminen)

---

**Nota**: Este documento asume que estás usando AAP 2.x o superior. Para versiones anteriores, la configuración puede variar ligeramente.

