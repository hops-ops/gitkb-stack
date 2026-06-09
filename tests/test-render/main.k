import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

_ready_conditions = [
    {type = "Ready", status = "True"}
    {type = "Synced", status = "True"}
]

_base_xr = {
    apiVersion = "hops.ops.com.ai/v1alpha1"
    kind = "GitKBStack"
    metadata = {
        name = "platform-kb"
        namespace = "default"
    }
    spec = {
        clusterName = "pat-local"
    }
}

items = [
    metav1alpha1.CompositionTest {
        metadata.name = "minimal-renders-namespace-and-helm-release"
        spec = {
            compositionPath = "apis/gitkbstacks/composition.yaml"
            xrdPath = "apis/gitkbstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = _base_xr
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "platform-kb-namespace"
                    spec.forProvider.manifest = {
                        apiVersion = "v1"
                        kind = "Namespace"
                        metadata.name = "gitkb"
                    }
                }
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "platform-kb"
                    spec.forProvider = {
                        chart = {
                            name = "gitkb-server"
                            repository = "https://hops-ops.github.io/gitkb-server-chart"
                            version = "0.1.0"
                        }
                        namespace = "gitkb"
                        values = {
                            fullnameOverride = "platform-kb-gitkb-server"
                            image.repository = "ghcr.io/hops-ops/gitkb-server"
                            image.tag = "v0.1.0"
                            gitkb.org = "hops-ops"
                            persistence.enabled = True
                        }
                    }
                    spec.providerConfigRef = {
                        name = "pat-local"
                        kind = "ProviderConfig"
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "gateway-dns-and-tls-render-when-exposure-enabled"
        spec = {
            compositionPath = "apis/gitkbstacks/composition.yaml"
            xrdPath = "apis/gitkbstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = _base_xr | {
                spec.exposure = {
                    enabled = True
                    domain = "ops.com.ai"
                    gatewayRef = {
                        name = "platform"
                        namespace = "istio-ingress"
                        sectionName = "https"
                    }
                    dns = {
                        enabled = True
                        ttl = "300"
                    }
                    certificate = {
                        enabled = True
                        secretName = "gitkb-tls"
                        secretNamespace = "istio-ingress"
                        issuerRef = {
                            name = "letsencrypt-production"
                            kind = "ClusterIssuer"
                        }
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "platform-kb-exposure-certificate"
                    spec.forProvider.manifest = {
                        apiVersion = "cert-manager.io/v1"
                        kind = "Certificate"
                        metadata = {
                            name = "gitkb-tls"
                            namespace = "istio-ingress"
                        }
                        spec = {
                            secretName = "gitkb-tls"
                            issuerRef = {
                                name = "letsencrypt-production"
                                kind = "ClusterIssuer"
                            }
                            dnsNames = ["kb.ops.com.ai"]
                        }
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "platform-kb-exposure-httproute"
                    spec.forProvider.manifest = {
                        apiVersion = "gateway.networking.k8s.io/v1"
                        kind = "HTTPRoute"
                        metadata = {
                            name = "platform-kb"
                            namespace = "gitkb"
                            annotations = {
                                "external-dns.alpha.kubernetes.io/hostname" = "kb.ops.com.ai"
                                "external-dns.alpha.kubernetes.io/ttl" = "300"
                            }
                        }
                        spec = {
                            parentRefs = [{
                                name = "platform"
                                namespace = "istio-ingress"
                                sectionName = "https"
                            }]
                            hostnames = ["kb.ops.com.ai"]
                            rules = [{
                                backendRefs = [{
                                    name = "platform-kb-gitkb-server"
                                    namespace = "gitkb"
                                    port = 8080
                                }]
                            }]
                        }
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "observed-ready-renders-usages-and-ready-status"
        spec = {
            compositionPath = "apis/gitkbstacks/composition.yaml"
            xrdPath = "apis/gitkbstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = _base_xr | {
                spec.exposure = {
                    enabled = True
                    domain = "ops.com.ai"
                    gatewayRef = {
                        name = "platform"
                        namespace = "istio-ingress"
                        sectionName = "https"
                    }
                    certificate = {
                        enabled = True
                        secretName = "gitkb-tls"
                        secretNamespace = "gitkb"
                        issuerRef = {
                            name = "letsencrypt-production"
                            kind = "ClusterIssuer"
                        }
                    }
                }
            }
            observedResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata = {
                        name = "platform-kb-namespace"
                        annotations = {"crossplane.io/composition-resource-name" = "namespace"}
                    }
                    status.conditions = _ready_conditions
                }
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata = {
                        name = "platform-kb"
                        annotations = {"crossplane.io/composition-resource-name" = "helm-release-gitkb"}
                    }
                    status.conditions = _ready_conditions
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata = {
                        name = "platform-kb-exposure-httproute"
                        annotations = {"crossplane.io/composition-resource-name" = "exposure-httproute"}
                    }
                    status.conditions = _ready_conditions
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata = {
                        name = "platform-kb-exposure-certificate"
                        annotations = {"crossplane.io/composition-resource-name" = "exposure-certificate"}
                    }
                    status.conditions = _ready_conditions
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata = {
                        name = "platform-kb-delete-gitkb-before-namespace"
                        annotations = {"crossplane.io/composition-resource-name" = "usage-gitkb-namespace"}
                    }
                    status.conditions = _ready_conditions
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata = {
                        name = "platform-kb-delete-httproute-before-gitkb"
                        annotations = {"crossplane.io/composition-resource-name" = "usage-httproute-gitkb"}
                    }
                    status.conditions = _ready_conditions
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata = {
                        name = "platform-kb-delete-httproute-before-namespace"
                        annotations = {"crossplane.io/composition-resource-name" = "usage-httproute-namespace"}
                    }
                    status.conditions = _ready_conditions
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata = {
                        name = "platform-kb-delete-certificate-before-namespace"
                        annotations = {"crossplane.io/composition-resource-name" = "usage-certificate-namespace"}
                    }
                    status.conditions = _ready_conditions
                }
            ]
            assertResources = [
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "platform-kb-delete-gitkb-before-namespace"
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "platform-kb-delete-httproute-before-gitkb"
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "platform-kb-delete-httproute-before-namespace"
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "platform-kb-delete-certificate-before-namespace"
                }
                {
                    apiVersion = "hops.ops.com.ai/v1alpha1"
                    kind = "GitKBStack"
                    metadata.name = "platform-kb"
                    status = {
                        ready = True
                        exposure = {
                            routeReady = True
                            certificateReady = True
                        }
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "provider-config-refs-and-values-merge"
        spec = {
            compositionPath = "apis/gitkbstacks/composition.yaml"
            xrdPath = "apis/gitkbstacks/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = _base_xr | {
                spec = {
                    clusterName = "pat-local"
                    providerConfigRefs = {
                        helm.name = "helm-pc"
                        kubernetes.name = "k8s-pc"
                    }
                    values = {
                        persistence.size = "20Gi"
                        service.annotations = {
                            "hops.ops.com.ai/test" = "true"
                        }
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "platform-kb"
                    spec.providerConfigRef.name = "helm-pc"
                    spec.forProvider.values = {
                        persistence.size = "20Gi"
                        service.annotations = {
                            "hops.ops.com.ai/test" = "true"
                        }
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "platform-kb-namespace"
                    spec.providerConfigRef.name = "k8s-pc"
                }
            ]
        }
    }
]
