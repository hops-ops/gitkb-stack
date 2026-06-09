# gitkb-stack

GitKB installs a GitKB sync server into Kubernetes and can expose many knowledge bases on one Gateway using repository-style paths such as `https://kb.ops.com.ai/hops-ops/hops`.

The XR installs the Hops `gitkb-server` chart from the GitHub Pages Helm repository at `https://hops-ops.github.io/gitkb-server-chart`.

## Why GitKB?

**Without GitKB:**

- Agents keep local context that is hard to share across sessions.
- Each knowledge base needs hand-managed storage, routing, and lifecycle.
- Multiple repos behind one public endpoint require bespoke Gateway routes.

**With GitKB:**

- A single `GitKB` claim installs the server, storage, and Kubernetes wiring.
- `spec.gitkb.org` and `spec.gitkb.repo` derive predictable public paths.
- Gateway API, ExternalDNS, and optional cert-manager resources are rendered together.

## The Journey

## Getting Started

Start with an internal-only install:

```yaml
apiVersion: hops.ops.com.ai/v1alpha1
kind: GitKB
metadata:
  name: gitkb
spec:
  clusterName: pat-local
  namespace: gitkb
```

The chart creates a single GitKB StatefulSet, ClusterIP Service, and persistent volume by default. Set `persistence.enabled: false` for disposable local tests.

## Growing

Enable Gateway API exposure when the cluster already has a platform Gateway and ExternalDNS watching HTTPRoutes:

```yaml
spec:
  gitkb:
    org: hops-ops
    repo: hops
  exposure:
    enabled: true
    domain: kb.ops.com.ai
    gatewayRef:
      name: platform
      namespace: istio-ingress
      sectionName: https
```

This renders an unauthenticated `HTTPRoute` for `spec.exposure.domain` and annotates it for ExternalDNS.

By default, the public route path is derived from `spec.gitkb.org` and `spec.gitkb.repo`:

```text
https://kb.ops.com.ai/hops-ops/hops
```

The HTTPRoute matches that prefix and uses Gateway API `URLRewrite` to strip it before forwarding to `git-kb serve`. That lets multiple GitKB repos share one domain:

```yaml
spec:
  gitkb:
    org: hops-ops
    repo: hops
```

Override `exposure.pathPrefix` only when the public path should differ from `/<org>/<repo>`. For a dedicated domain, set `pathPrefix: /`.

## Enterprise Scale

If the Gateway does not already serve a wildcard certificate for the domain, enable the cert-manager Certificate. The Gateway listener still needs to reference the resulting Secret; this stack does not mutate the Gateway object.

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

To keep an existing PVC, set `persistence.existingClaim` and leave `persistence.enabled: true`.

## Using GitKB

Configure the GitKB CLI remote to the status URL or to the same domain and repo path:

```toml
[sync.remotes.origin]
url = "https://kb.ops.com.ai/hops-ops/hops"
```

The server route strips `/hops-ops/hops` before forwarding traffic to `git-kb serve`, so the CLI talks to the normal GitKB endpoints under that public path.

## Status

The XR publishes the operational fields needed by downstream automation:

- `status.ready` - true when namespace, Helm release, route, certificate, and usage protections are ready.
- `status.release` - Helm release name, namespace, and readiness.
- `status.service` - backend Service name, namespace, and port.
- `status.exposure.domain` - public domain from `spec.exposure.domain`.
- `status.exposure.pathPrefix` - effective path prefix, defaulting to `/<org>/<repo>`.
- `status.exposure.url` - full public URL for the GitKB remote.
- `status.exposure.routeReady` - composed HTTPRoute readiness.
- `status.exposure.certificateReady` - composed Certificate readiness when enabled.

## Composed Resources

- `helm.m.crossplane.io/Release` - installs the `gitkb-server` chart.
- `kubernetes.m.crossplane.io/Object` Namespace - creates the target namespace.
- `kubernetes.m.crossplane.io/Object` HTTPRoute - optional Gateway API route when `exposure.enabled` is true.
- `kubernetes.m.crossplane.io/Object` Certificate - optional cert-manager Certificate when `exposure.certificate.enabled` is true.
- `protection.crossplane.io/Usage` - protects dependency deletion order once resources are ready.

## Development

```bash
make test
make render:all
make validate:all
make build
```

For local control-plane testing:

```bash
hops config install --path xrs/stacks/k8s/gitkb --context colima
kubectl --context colima apply -f local/gitkb.yaml
```

## License

Apache-2.0
