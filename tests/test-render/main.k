import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

_ready_conditions = [
    {type = "Ready", status = "True"}
    {type = "Synced", status = "True"}
]

_base_xr = {
    apiVersion = "hops.ops.com.ai/v1alpha1"
    kind = "GitKB"
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
            compositionPath = "apis/gitkbs/composition.yaml"
            xrdPath = "apis/gitkbs/definition.yaml"
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
                            version = "0.2.1"
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
            compositionPath = "apis/gitkbs/composition.yaml"
            xrdPath = "apis/gitkbs/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = _base_xr | {
                spec.gitkb = {
                    org = "hops-ops"
                    repo = "hops"
                    name = "Hops Knowledge Base"
                }
                spec.exposure = {
                    enabled = True
                    domain = "kb.ops.com.ai"
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
                                matches = [{
                                    path = {
                                        type = "PathPrefix"
                                        value = "/hops-ops/hops"
                                    }
                                }]
                                filters = [{
                                    type = "URLRewrite"
                                    urlRewrite.path = {
                                        type = "ReplacePrefixMatch"
                                        replacePrefixMatch = "/"
                                    }
                                }]
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
        metadata.name = "istio-jwt-auth-renders-waypoint-and-policies"
        spec = {
            compositionPath = "apis/gitkbs/composition.yaml"
            xrdPath = "apis/gitkbs/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = _base_xr | {
                spec.auth = {
                    istioJwt = {
                        enabled = True
                        issuer = "https://auth.ops.com.ai"
                        jwksUri = "https://auth.ops.com.ai/oauth/v2/keys"
                        audiences = ["gitkb-project-audience"]
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "platform-kb-namespace"
                    spec.forProvider.manifest.metadata.labels = {
                        "istio.io/dataplane-mode" = "ambient"
                    }
                }
                {
                    apiVersion = "helm.m.crossplane.io/v1beta1"
                    kind = "Release"
                    metadata.name = "platform-kb"
                    spec.forProvider.values.service.labels = {
                        "istio.io/use-waypoint" = "platform-kb-waypoint"
                        "istio.io/ingress-use-waypoint" = "true"
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "platform-kb-auth-waypoint"
                    spec.forProvider.manifest = {
                        apiVersion = "gateway.networking.k8s.io/v1"
                        kind = "Gateway"
                        metadata = {
                            name = "platform-kb-waypoint"
                            namespace = "gitkb"
                            labels = {
                                "istio.io/waypoint-for" = "service"
                            }
                        }
                        spec = {
                            gatewayClassName = "istio-waypoint"
                            listeners = [{
                                name = "mesh"
                                port = 15008
                                protocol = "HBONE"
                                allowedRoutes.namespaces.from = "Same"
                            }]
                        }
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "platform-kb-auth-requestauthentication"
                    spec.forProvider.manifest = {
                        apiVersion = "security.istio.io/v1"
                        kind = "RequestAuthentication"
                        metadata = {
                            name = "platform-kb-jwt"
                            namespace = "gitkb"
                        }
                        spec = {
                            targetRefs = [{
                                group = ""
                                kind = "Service"
                                name = "platform-kb-gitkb-server"
                            }]
                            jwtRules = [{
                                issuer = "https://auth.ops.com.ai"
                                jwksUri = "https://auth.ops.com.ai/oauth/v2/keys"
                                audiences = ["gitkb-project-audience"]
                            }]
                        }
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "platform-kb-auth-authorizationpolicy"
                    spec.forProvider.manifest = {
                        apiVersion = "security.istio.io/v1"
                        kind = "AuthorizationPolicy"
                        metadata = {
                            name = "platform-kb-require-jwt"
                            namespace = "gitkb"
                        }
                        spec = {
                            targetRefs = [{
                                group = ""
                                kind = "Service"
                                name = "platform-kb-gitkb-server"
                            }]
                            action = "ALLOW"
                            rules = [{
                                from = [{
                                    source.requestPrincipals = ["*"]
                                }]
                            }]
                        }
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "oidc-client-renders-zitadel-identity"
        spec = {
            compositionPath = "apis/gitkbs/composition.yaml"
            xrdPath = "apis/gitkbs/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = _base_xr | {
                spec.auth = {
                    oidcClient = {
                        enabled = True
                        issuer = "https://auth.ops.com.ai"
                        jwksUri = "https://auth.ops.com.ai/oauth/v2/keys"
                        zitadelProviderConfigRef = {
                            name = "zitadel-tenant-stack"
                            kind = "ProviderConfig"
                        }
                        zitadelOrgId = "org-123"
                        projectName = "gitkb"
                        device = {
                            applicationName = "gitkb-cli"
                        }
                        machine = {
                            userName = "gitkb-sync"
                        }
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "project.zitadel.m.crossplane.io/v1alpha1"
                    kind = "Project"
                    metadata.name = "platform-kb-auth-zitadel-project"
                    spec.forProvider = {
                        orgId = "org-123"
                        name = "gitkb"
                        hasProjectCheck = False
                        projectRoleAssertion = True
                        projectRoleCheck = False
                    }
                    spec.providerConfigRef = {
                        name = "zitadel-tenant-stack"
                        kind = "ProviderConfig"
                    }
                }
                {
                    apiVersion = "project.zitadel.m.crossplane.io/v1alpha1"
                    kind = "Role"
                    metadata.name = "platform-kb-auth-zitadel-role"
                    spec.forProvider = {
                        orgId = "org-123"
                        projectIdRef.name = "platform-kb-auth-zitadel-project"
                        roleKey = "gitkb:sync"
                        displayName = "GitKB Sync"
                        group = "gitkb"
                    }
                }
                {
                    apiVersion = "application.zitadel.m.crossplane.io/v1alpha1"
                    kind = "Oidc"
                    metadata.name = "platform-kb-auth-zitadel-device-app"
                    spec.forProvider = {
                        name = "gitkb-cli"
                        projectIdRef.name = "platform-kb-auth-zitadel-project"
                        appType = "OIDC_APP_TYPE_NATIVE"
                        authMethodType = "OIDC_AUTH_METHOD_TYPE_NONE"
                        grantTypes = [
                            "OIDC_GRANT_TYPE_DEVICE_CODE"
                            "OIDC_GRANT_TYPE_REFRESH_TOKEN"
                        ]
                        redirectUris = ["http://localhost"]
                        responseTypes = ["OIDC_RESPONSE_TYPE_CODE"]
                        accessTokenType = "OIDC_TOKEN_TYPE_JWT"
                        accessTokenRoleAssertion = True
                        idTokenRoleAssertion = True
                        idTokenUserinfoAssertion = True
                    }
                    spec.writeConnectionSecretToRef.name = "gitkb-cli-oidc-client"
                }
                {
                    apiVersion = "user.zitadel.m.crossplane.io/v1alpha1"
                    kind = "MachineUser"
                    metadata.name = "platform-kb-auth-zitadel-machineuser"
                    spec.forProvider = {
                        orgId = "org-123"
                        userName = "gitkb-sync"
                        accessTokenType = "ACCESS_TOKEN_TYPE_JWT"
                        withSecret = True
                    }
                    spec.writeConnectionSecretToRef.name = "gitkb-sync-secret"
                }
                {
                    apiVersion = "hops.ops.com.ai/v1alpha1"
                    kind = "GitKB"
                    metadata.name = "platform-kb"
                    status.auth.oidcClient = {
                        enabled = True
                        rendered = True
                        issuer = "https://auth.ops.com.ai"
                        device = {
                            clientSecretRef = {
                                name = "gitkb-cli-oidc-client"
                                namespace = "default"
                                clientIdKey = "attribute.client_id"
                                clientSecretKey = "attribute.client_secret"
                            }
                        }
                        machine = {
                            clientSecretRef = {
                                name = "gitkb-sync-secret"
                                namespace = "default"
                                clientIdKey = "attribute.client_id"
                                clientSecretKey = "attribute.client_secret"
                            }
                        }
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "oidc-client-observed-project-becomes-istio-audience"
        spec = {
            compositionPath = "apis/gitkbs/composition.yaml"
            xrdPath = "apis/gitkbs/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = _base_xr | {
                spec.auth = {
                    oidcClient = {
                        enabled = True
                        issuer = "https://auth.ops.com.ai"
                        jwksUri = "https://auth.ops.com.ai/oauth/v2/keys"
                        zitadelProviderConfigRef = {
                            name = "zitadel-tenant-stack"
                            kind = "ProviderConfig"
                        }
                        zitadelOrgId = "org-123"
                        projectName = "gitkb"
                        device = {
                            applicationName = "gitkb-cli"
                        }
                        machine = {
                            userName = "gitkb-sync"
                        }
                    }
                    istioJwt = {
                        enabled = True
                    }
                }
            }
            observedResources = [
                {
                    apiVersion = "project.zitadel.m.crossplane.io/v1alpha1"
                    kind = "Project"
                    metadata = {
                        name = "platform-kb-auth-zitadel-project"
                        annotations = {"crossplane.io/composition-resource-name" = "auth-zitadel-project"}
                    }
                    status = {
                        atProvider.id = "gitkb-project-id"
                        conditions = _ready_conditions
                    }
                }
                {
                    apiVersion = "project.zitadel.m.crossplane.io/v1alpha1"
                    kind = "Role"
                    metadata = {
                        name = "platform-kb-auth-zitadel-role"
                        annotations = {"crossplane.io/composition-resource-name" = "auth-zitadel-role"}
                    }
                    status.conditions = _ready_conditions
                }
                {
                    apiVersion = "application.zitadel.m.crossplane.io/v1alpha1"
                    kind = "Oidc"
                    metadata = {
                        name = "platform-kb-auth-zitadel-device-app"
                        annotations = {"crossplane.io/composition-resource-name" = "auth-zitadel-device-app"}
                    }
                    status = {
                        atProvider.id = "gitkb-cli-app-id"
                        conditions = _ready_conditions
                    }
                }
                {
                    apiVersion = "user.zitadel.m.crossplane.io/v1alpha1"
                    kind = "MachineUser"
                    metadata = {
                        name = "platform-kb-auth-zitadel-machineuser"
                        annotations = {"crossplane.io/composition-resource-name" = "auth-zitadel-machineuser"}
                    }
                    status = {
                        atProvider = {
                            id = "gitkb-user-id"
                            userName = "gitkb-sync"
                        }
                        conditions = _ready_conditions
                    }
                }
            ]
            assertResources = [
                {
                    apiVersion = "user.zitadel.m.crossplane.io/v1alpha1"
                    kind = "Grant"
                    metadata.name = "platform-kb-auth-zitadel-grant"
                    spec.forProvider = {
                        orgId = "org-123"
                        projectId = "gitkb-project-id"
                        userId = "gitkb-user-id"
                        roleKeys = ["gitkb:sync"]
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "platform-kb-auth-requestauthentication"
                    spec.forProvider.manifest.spec.jwtRules = [{
                        issuer = "https://auth.ops.com.ai"
                        jwksUri = "https://auth.ops.com.ai/oauth/v2/keys"
                        audiences = ["gitkb-project-id"]
                    }]
                }
                {
                    apiVersion = "hops.ops.com.ai/v1alpha1"
                    kind = "GitKB"
                    metadata.name = "platform-kb"
                    status.auth = {
                        oidcClient = {
                            enabled = True
                            rendered = True
                            projectId = "gitkb-project-id"
                            device = {
                                applicationId = "gitkb-cli-app-id"
                                ready = True
                            }
                            machine = {
                                clientId = "gitkb-sync"
                                userId = "gitkb-user-id"
                                ready = True
                            }
                            projectReady = True
                            roleReady = True
                            grantReady = False
                        }
                        istioJwt = {
                            enabled = True
                            rendered = True
                            issuer = "https://auth.ops.com.ai"
                            audiences = ["gitkb-project-id"]
                        }
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "observed-auth-ready-renders-usages-and-ready-status"
        spec = {
            compositionPath = "apis/gitkbs/composition.yaml"
            xrdPath = "apis/gitkbs/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = _base_xr | {
                spec.auth = {
                    istioJwt = {
                        enabled = True
                        issuer = "https://auth.ops.com.ai"
                        jwksUri = "https://auth.ops.com.ai/oauth/v2/keys"
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
                        name = "platform-kb-auth-waypoint"
                        annotations = {"crossplane.io/composition-resource-name" = "auth-waypoint"}
                    }
                    status.conditions = _ready_conditions
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata = {
                        name = "platform-kb-auth-requestauthentication"
                        annotations = {"crossplane.io/composition-resource-name" = "auth-requestauthentication"}
                    }
                    status.conditions = _ready_conditions
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata = {
                        name = "platform-kb-auth-authorizationpolicy"
                        annotations = {"crossplane.io/composition-resource-name" = "auth-authorizationpolicy"}
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
                        name = "platform-kb-delete-auth-waypoint-before-namespace"
                        annotations = {"crossplane.io/composition-resource-name" = "usage-auth-waypoint-namespace"}
                    }
                    status.conditions = _ready_conditions
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata = {
                        name = "platform-kb-delete-auth-jwt-before-namespace"
                        annotations = {"crossplane.io/composition-resource-name" = "usage-auth-jwt-namespace"}
                    }
                    status.conditions = _ready_conditions
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata = {
                        name = "platform-kb-delete-auth-policy-before-namespace"
                        annotations = {"crossplane.io/composition-resource-name" = "usage-auth-policy-namespace"}
                    }
                    status.conditions = _ready_conditions
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata = {
                        name = "platform-kb-delete-auth-jwt-before-gitkb"
                        annotations = {"crossplane.io/composition-resource-name" = "usage-auth-jwt-gitkb"}
                    }
                    status.conditions = _ready_conditions
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata = {
                        name = "platform-kb-delete-auth-policy-before-gitkb"
                        annotations = {"crossplane.io/composition-resource-name" = "usage-auth-policy-gitkb"}
                    }
                    status.conditions = _ready_conditions
                }
            ]
            assertResources = [
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "platform-kb-delete-auth-waypoint-before-namespace"
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "platform-kb-delete-auth-jwt-before-namespace"
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "platform-kb-delete-auth-policy-before-namespace"
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "platform-kb-delete-auth-jwt-before-gitkb"
                }
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "platform-kb-delete-auth-policy-before-gitkb"
                }
                {
                    apiVersion = "hops.ops.com.ai/v1alpha1"
                    kind = "GitKB"
                    metadata.name = "platform-kb"
                    status = {
                        ready = True
                        auth.istioJwt = {
                            enabled = True
                            rendered = True
                            issuer = "https://auth.ops.com.ai"
                            waypointReady = True
                            requestAuthenticationReady = True
                            authorizationPolicyReady = True
                        }
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "observed-ready-renders-usages-and-ready-status"
        spec = {
            compositionPath = "apis/gitkbs/composition.yaml"
            xrdPath = "apis/gitkbs/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = _base_xr | {
                spec.gitkb = {
                    org = "hops-ops"
                    repo = "hops"
                    name = "Hops Knowledge Base"
                }
                spec.exposure = {
                    enabled = True
                    domain = "kb.ops.com.ai"
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
                    kind = "GitKB"
                    metadata.name = "platform-kb"
                    status = {
                        ready = True
                        exposure = {
                            pathPrefix = "/hops-ops/hops"
                            url = "https://kb.ops.com.ai/hops-ops/hops"
                            routeReady = True
                            certificateReady = True
                        }
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "root-path-prefix-keeps-root-route-without-rewrite"
        spec = {
            compositionPath = "apis/gitkbs/composition.yaml"
            xrdPath = "apis/gitkbs/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = _base_xr | {
                spec.exposure = {
                    enabled = True
                    domain = "kb.ops.com.ai"
                    pathPrefix = "/"
                    gatewayRef = {
                        name = "platform"
                        namespace = "istio-ingress"
                        sectionName = "https"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "platform-kb-exposure-httproute"
                    spec.forProvider.manifest.spec.rules = [{
                        matches = [{
                            path = {
                                type = "PathPrefix"
                                value = "/"
                            }
                        }]
                        backendRefs = [{
                            name = "platform-kb-gitkb-server"
                            namespace = "gitkb"
                            port = 8080
                        }]
                    }]
                }
                {
                    apiVersion = "hops.ops.com.ai/v1alpha1"
                    kind = "GitKB"
                    metadata.name = "platform-kb"
                    status.exposure = {
                        pathPrefix = "/"
                        url = "https://kb.ops.com.ai"
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "provider-config-refs-and-values-merge"
        spec = {
            compositionPath = "apis/gitkbs/composition.yaml"
            xrdPath = "apis/gitkbs/definition.yaml"
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
