# Configuración del Token de GitHub en AAP

Esta guía explica las diferentes formas de manejar el token de GitHub de forma segura en Ansible Automation Platform (AAP) cuando usas Survey.

## 🎯 Opciones Disponibles

### Opción 1: Credential de Tipo "Source Control" (⭐ RECOMENDADA)

Esta es la **mejor práctica** porque:
- ✅ El token se almacena de forma segura (encriptado)
- ✅ No aparece en los logs
- ✅ Se puede reutilizar en múltiples Job Templates
- ✅ Se puede rotar fácilmente

#### Pasos:

1. **Crear el Credential en AAP:**
   - Ve a **Resources > Credentials**
   - Click en **"Add"** o **"+"**
   - Selecciona tipo: **"Source Control"**
   - Configura:
     - **Name**: `GitHub Token - Compliance GitOps`
     - **Organization**: Tu organización
     - **Credential Type**: `Source Control`
     - **Type**: `Git`
     - **Username**: Tu usuario de GitHub (ej: `Snakerrrr`)
     - **Password/Token**: Tu Personal Access Token de GitHub
     - **Description**: "Token para operaciones GitOps de Compliance"

2. **Asociar el Credential al Job Template:**
   - Ve a tu Job Template: **"Auditoria Compliance Multi-Cluster"**
   - En la pestaña **"Details"**, busca la sección **"Credentials"**
   - Click en **"+"** para agregar un credential
   - Selecciona: **"GitHub Token - Compliance GitOps"**
   - **Tipo**: `Source Control`

3. **Modificar el Playbook para usar el Credential:**

   El credential de Source Control en AAP se inyecta automáticamente como variables de entorno. Necesitas modificar el playbook para leerlo:

   **Opción A: Usar lookup de variables de entorno (Recomendado)**

   En `playbooks/orchestrator_aap_multicluster.yml`, modifica la sección de GitOps:

   ```yaml
   - name: Ejecutar Fase GitOps (Configuración Global)
     include_role:
       name: gitops_policy_update
     vars:
       # AAP inyecta el token del credential como variable de entorno
       # El nombre depende de cómo AAP lo inyecta, típicamente:
       github_token: "{{ lookup('env', 'GIT_TOKEN') | default(lookup('env', 'SCM_TOKEN') | default(github_token | default(''))) }}"
       github_user: "{{ lookup('env', 'GIT_USER') | default(github_user | default('Snakerrrr')) }}"
     when: do_gitops | default(false) | bool
   ```

   **Opción B: Usar el credential directamente (Más simple)**

   AAP puede inyectar el credential automáticamente. Verifica en los logs del job qué variables de entorno se crean. Típicamente son:
   - `GIT_TOKEN` o `SCM_TOKEN` para el token
   - `GIT_USER` para el usuario

---

### Opción 2: Survey con Tipo "Password" (Para entrada dinámica)

Si necesitas que el usuario ingrese el token cada vez que ejecuta el job:

#### Pasos:

1. **Agregar pregunta en Survey:**
   - Ve a la pestaña **"Survey"** de tu Job Template
   - Click en **"Create survey question"**
   - Configura:
     - **Variable name**: `github_token`
     - **Question**: `Token de GitHub para GitOps`
     - **Answer variable name**: `github_token`
     - **Field type**: `Password` ⭐ (Esto oculta el texto)
     - **Required**: ✅ (marcar como requerido)
     - **Default**: (dejar vacío)
     - **Description**: `Ingresa tu Personal Access Token de GitHub. Se requiere solo si "¿Aplicar cambios en GitOps?" es true.`

2. **Hacer la pregunta condicional (Opcional pero recomendado):**

   Puedes hacer que la pregunta del token solo aparezca si `do_gitops=true`:

   - En la pregunta del token, agrega en **"Min/Max length"** o usa lógica condicional
   - O simplemente deja que el playbook valide si falta el token cuando `do_gitops=true`

3. **El playbook ya está listo:**

   El playbook `orchestrator_aap_multicluster.yml` ya lee `github_token` directamente:

   ```yaml
   github_token: "{{ github_token | default('') }}"
   ```

   ✅ **No necesitas modificar nada**, solo agregar la pregunta en Survey.

---

### Opción 3: Variable de Entorno en Job Template (Para tokens fijos)

Si el token es el mismo siempre y no quieres que los usuarios lo ingresen:

#### Pasos:

1. **En el Job Template, pestaña "Details":**
   - Busca la sección **"Environment Variables"** o **"Variables de Entorno"**
   - Agrega:
     ```
     GITHUB_TOKEN=tu_token_aqui
     ```

2. **Modificar el playbook para leer la variable de entorno:**

   ```yaml
   - name: Ejecutar Fase GitOps (Configuración Global)
     include_role:
       name: gitops_policy_update
     vars:
       github_token: "{{ lookup('env', 'GITHUB_TOKEN') | default(github_token | default('')) }}"
     when: do_gitops | default(false) | bool
   ```

---

### Opción 4: Credential Personalizado (Avanzado)

Para máximo control, puedes crear un credential personalizado:

1. **Crear Credential:**
   - Tipo: `Machine` o `Custom`
   - Agregar campo personalizado: `github_token`
   - Guardar el token allí

2. **Usar en el playbook:**
   - AAP inyecta los campos del credential como variables
   - Acceder vía `{{ github_token }}` directamente

---

## 📋 Comparación de Opciones

| Opción | Seguridad | Facilidad | Reutilización | Recomendado Para |
|--------|-----------|-----------|---------------|------------------|
| **Source Control Credential** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Producción |
| **Survey Password** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | Desarrollo/Testing |
| **Variable de Entorno** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | Tokens fijos |
| **Credential Personalizado** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | Casos especiales |

---

## 🎯 Recomendación para tu Caso

Basándome en tu configuración actual con Survey, te recomiendo:

### **Opción Híbrida (Mejor de ambos mundos):**

1. **Crear un Credential de Source Control** con el token por defecto
2. **Agregar una pregunta opcional en Survey** tipo password para `github_token`
3. **Modificar el playbook** para priorizar el Survey sobre el Credential:

```yaml
- name: Ejecutar Fase GitOps (Configuración Global)
  include_role:
    name: gitops_policy_update
  vars:
    # Prioridad: Survey > Credential > Default vacío
    github_token: "{{ github_token | default(lookup('env', 'GIT_TOKEN') | default(lookup('env', 'SCM_TOKEN') | default(''))) }}"
    github_user: "{{ github_user | default(lookup('env', 'GIT_USER') | default('Snakerrrr')) }}"
  when: do_gitops | default(false) | bool
```

**Ventajas:**
- ✅ Token por defecto seguro (Credential)
- ✅ Flexibilidad para usar otro token (Survey)
- ✅ No aparece en logs si viene del Credential
- ✅ Usuarios pueden usar el token por defecto sin ingresarlo

---

## 📝 Ejemplo de Configuración Completa en Survey

Basándome en tu Survey actual, aquí está la configuración recomendada:

### Preguntas Actuales:
1. ✅ "Selecciona los clusters a auditar" - `survey_target_clusters` (multiselect)
2. ✅ "¿Aplicar cambios en GitOps?" - `do_gitops` (multiplechoice, default: false)
3. ✅ "Enviar reporte por correo?" - `do_send_email` (multiplechoice, default: false)

### Pregunta Adicional Recomendada:
4. **"Token de GitHub (opcional)"** - `github_token` (password, default: vacío)
   - **Variable name**: `github_token`
   - **Field type**: `Password`
   - **Required**: ❌ (No requerido, usará el Credential si está vacío)
   - **Description**: `Opcional. Si está vacío, se usará el token del Credential configurado. Solo necesario si "¿Aplicar cambios en GitOps?" es true.`

---

## 🔧 Modificación del Playbook para Soporte Híbrido

Actualiza `playbooks/orchestrator_aap_multicluster.yml`:

```yaml
- name: Ejecutar Fase GitOps (Configuración Global)
  include_role:
    name: gitops_policy_update
  vars:
    # Prioridad: Survey > Credential (GIT_TOKEN/SCM_TOKEN) > Default
    github_token: "{{ github_token | default(lookup('env', 'GIT_TOKEN') | default(lookup('env', 'SCM_TOKEN') | default(''))) }}"
    github_user: "{{ github_user | default(lookup('env', 'GIT_USER') | default('Snakerrrr')) }}"
    gitops_repo_path: "{{ gitops_repo_path | default('/tmp/acm-policies') }}"
    gitops_repo_branch: "{{ gitops_repo_branch | default('main') }}"
    run_cis: "{{ run_cis | default(true) }}"
    run_pci: "{{ run_pci | default(false) }}"
  when: do_gitops | default(false) | bool
```

---

## ✅ Checklist de Implementación

- [ ] Crear Credential de tipo "Source Control" con el token
- [ ] Asociar el Credential al Job Template
- [ ] (Opcional) Agregar pregunta `github_token` tipo password en Survey
- [ ] Modificar el playbook para leer el token con prioridad correcta
- [ ] Probar ejecución con `do_gitops=true`
- [ ] Verificar que el token no aparece en los logs

---

## 🔒 Seguridad

**IMPORTANTE**: 
- ❌ **NUNCA** pongas el token en "Extra Variables" (aparece en logs)
- ✅ **SIEMPRE** usa Credentials o Survey tipo Password
- ✅ **ROTA** el token periódicamente
- ✅ **USA** Personal Access Tokens con permisos mínimos necesarios

---

¿Necesitas ayuda con alguna de estas opciones? Puedo ayudarte a implementar la que prefieras.

