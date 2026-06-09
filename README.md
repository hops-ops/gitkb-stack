# gitkb-stack

GitKBStack installs a GitKB sync server into Kubernetes using the Hops `gitkb-server` chart.

## Getting Started

Start with an internal-only install:

```yaml
apiVersion: hops.ops.com.ai/v1alpha1
kind: GitKBStack
metadata:
  name: gitkb
spec:
  clusterName: pat-local
  namespace: gitkb
```

The chart creates a single GitKB StatefulSet, ClusterIP Service, and persistent volume by default.

## Growing

Enable Gateway API exposure when the cluster already has a platform Gateway and ExternalDNS watching HTTPRoutes:

```yaml
spec:
  exposure:
    enabled: true
    domain: ops.com.ai
    gatewayRef:
      name: platform
      namespace: istio-ingress
      sectionName: https
```

This renders an unauthenticated `HTTPRoute` for `kb.<domain>` and annotates it for ExternalDNS.

## Enterprise Scale

If the Gateway does not already serve a wildcard certificate for the hostname, enable the cert-manager Certificate. The Gateway listener still needs to reference the resulting Secret; this stack does not mutate the Gateway object.

```yaml
spec:
  exposure:
    certificate:
      enabled: true
      secretName: gitkb-tls
      secretNamespace: istio-ingress
      issuerRef:
        name: letsencrypt-production
        kind: ClusterIssuer
```

Authentication is intentionally not part of this pass. Public installs should add Gateway/OIDC policy before exposing writable GitKB sync traffic beyond trusted networks.

## Import Existing

Use the chart seed settings to restore an existing KB from a Secret-backed backup or bundle:

```yaml
spec:
  seed:
    mode: backup
    secretRef:
      name: gitkb-backup
      key: backup.json
```
