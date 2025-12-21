# Configuración de ScanSetting para Escaneos Periódicos

## Resumen

Este documento explica cómo configurar escaneos periódicos de compliance usando `ScanSetting` con schedule (cron) en lugar de esperar manualmente a que los escaneos completen.

## ¿Por qué usar ScanSetting con schedule?

- **Automático**: Los escaneos se ejecutan automáticamente según el schedule configurado
- **Nativo**: Funcionalidad nativa del Compliance Operator, no requiere lógica externa
- **Confiable**: Evita problemas de condición de carrera (race conditions)
- **Mantenible**: No requiere esperar manualmente a que los escaneos completen

## Configuración

### 1. Variables del Playbook

El playbook ahora incluye variables para configurar el ScanSetting:

```yaml
# Schedule en formato cron para escaneos periódicos
# Ejemplo: "0 1 * * *" = Todos los días a la 1:00 AM
# Ejemplo: "0 */6 * * *" = Cada 6 horas
scan_schedule: "0 1 * * *"
scan_setting_name: "default"
```

### 2. Ejecutar el Playbook

El playbook automáticamente:
1. Crea el `ScanSetting` con el schedule configurado
2. Lo agrega al repositorio GitOps
3. ArgoCD lo sincroniza al cluster

Ejemplo de ejecución:

```bash
./scripts/ejecutar-playbook-hub.sh \
  -e "github_token=XXX \
      do_gitops=true \
      do_export_html=true \
      placement_label_key=environment \
      placement_label_value=cluster-2 \
      target_cluster_context=cluster-2 \
      scan_remediation_action=enforce \
      install_operator_remediation_action=enforce \
      scan_schedule='0 1 * * *'"
```

### 3. Formatos de Schedule (Cron)

El schedule sigue el formato estándar de cron:

```
┌───────────── minuto (0 - 59)
│ ┌───────────── hora (0 - 23)
│ │ ┌───────────── día del mes (1 - 31)
│ │ │ ┌───────────── mes (1 - 12)
│ │ │ │ ┌───────────── día de la semana (0 - 6) (domingo a sábado)
│ │ │ │ │
* * * * *
```

Ejemplos comunes:

- `"0 1 * * *"` - Todos los días a la 1:00 AM
- `"0 */6 * * *"` - Cada 6 horas
- `"0 0 * * 0"` - Todos los domingos a medianoche
- `"0 0 1 * *"` - El primer día de cada mes a medianoche
- `"0 9-17 * * 1-5"` - Cada hora entre 9 AM y 5 PM, de lunes a viernes

### 4. Archivos Generados

El playbook genera los siguientes archivos en el repositorio GitOps:

```
acm-policies/
├── base/
│   └── policy-generator-config.yaml  # Incluye referencia a scan-setting
└── compliance-operator/
    └── scan-setting/
        └── scan-setting.yaml          # ScanSetting con schedule
```

### 5. Modificar ComplianceSuites Existentes

Para que los `ComplianceSuite` existentes usen el `ScanSetting` con schedule, necesitas modificar sus manifiestos en el repositorio GitOps para que referencien el `ScanSetting`:

```yaml
apiVersion: compliance.openshift.io/v1alpha1
kind: ComplianceSuite
metadata:
  name: cis-profile
  namespace: openshift-compliance
spec:
  # Referenciar el ScanSetting con schedule
  scanSetting:
    name: default  # Nombre del ScanSetting creado
    kind: ScanSetting
  # ... resto de configuración ...
```

**Nota**: Si tus `ComplianceSuite` ya están configurados en el repositorio GitOps, necesitarás actualizarlos manualmente para que referencien el `ScanSetting`. El playbook solo crea el `ScanSetting`, no modifica los `ComplianceSuite` existentes.

## Verificación

### Verificar que el ScanSetting se creó:

```bash
oc get scansetting -n openshift-compliance
```

### Verificar el schedule:

```bash
oc get scansetting default -n openshift-compliance -o yaml
```

### Verificar que los escaneos se ejecutan automáticamente:

```bash
# Ver ComplianceSuites
oc get compliancesuites -n openshift-compliance

# Ver ComplianceScans
oc get compliancescans -n openshift-compliance

# Ver el estado de un scan específico
oc get compliancesuite cis-profile -n openshift-compliance -o yaml
```

## Cambios Realizados

1. **Rol `compliance_wait` simplificado**: Eliminada toda la lógica de espera de ComplianceSuites y re-scan. Ahora solo espera la instalación del operador (opcional).

2. **Template `scan-setting.yaml.j2`**: Nuevo template que genera el `ScanSetting` con schedule configurable.

3. **Rol `toggle_policies` actualizado**: Ahora también renderiza el `ScanSetting` además del `policy-generator-config.yaml`.

4. **Playbook actualizado**: Incluye variables para configurar el schedule del `ScanSetting`.

## Próximos Pasos

1. Ejecutar el playbook con `do_gitops=true` para crear el `ScanSetting` en el repositorio GitOps.
2. Verificar que ArgoCD sincroniza el `ScanSetting` al cluster.
3. (Opcional) Modificar los `ComplianceSuite` existentes para que referencien el `ScanSetting`.
4. Verificar que los escaneos se ejecutan automáticamente según el schedule.

## Troubleshooting

### El ScanSetting no se crea

- Verificar que el playbook se ejecutó con `do_gitops=true`
- Verificar que el repositorio GitOps tiene permisos de escritura
- Revisar los logs del playbook para ver errores

### Los escaneos no se ejecutan automáticamente

- Verificar que el `ScanSetting` existe en el cluster: `oc get scansetting -n openshift-compliance`
- Verificar que los `ComplianceSuite` referencian el `ScanSetting` correctamente
- Verificar que el Compliance Operator está instalado y funcionando

### El schedule no funciona como se espera

- Verificar el formato del cron (usar herramientas online para validar)
- Verificar la zona horaria del cluster
- Revisar los logs del Compliance Operator: `oc logs -n openshift-compliance -l name=compliance-operator`

