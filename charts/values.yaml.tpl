{{- $crc := required "CRC settings" .Installer.Features.crc -}}
{{- $tas := required "TAS settings" .Installer.Features.trustedArtifactSigner -}}
{{- $tpa := required "TPA settings" .Installer.Features.trustedProfileAnalyzer -}}
{{- $keycloak := required "Keycloak settings" .Installer.Features.keycloak -}}
{{- $acs := required "Red Hat ACS settings" .Installer.Features.redHatAdvancedClusterSecurity -}}
{{- $gitops := required "GitOps settings" .Installer.Features.openShiftGitOps -}}
{{- $pipelines := required "Pipelines settings" .Installer.Features.openShiftPipelines -}}
{{- $quay := required "Quay settings" .Installer.Features.redHatQuay -}}
{{- $rhdh := required "RHDH settings" .Installer.Features.redHatDeveloperHub -}}
{{- $ingressDomain := required "OpenShift ingress domain" .OpenShift.Ingress.Domain -}}
---
debug:
  ci: false

#
# rhtap-openshift
#

openshift:
  projects:
{{- if $keycloak.Enabled }}
    - {{ $keycloak.Namespace }}
{{- end }}
{{- if $acs.Enabled }}
    - {{ $acs.Namespace }}
    - rhacs-operator
{{- end }}
{{- if $quay.Enabled }}
    - {{ $quay.Namespace }}
{{- end }}
{{- if $tas.Enabled }}
    - {{ $tas.Namespace }}
{{- end }}
{{- if $tpa.Enabled }}
    - rhbk-operator
    - minio-operator
    - {{ $tpa.Namespace }}
{{- end }}
{{- if $rhdh.Enabled }}
    - {{ $rhdh.Namespace }}
{{- end }}

#
# rhtap-subscriptions
#

{{- $argoCDNamespace := .Installer.Namespace }}

subscriptions:
  amqStreams:
    enabled: {{ $tpa.Enabled }}
  crunchyData:
    enabled: {{ or $tpa.Enabled $rhdh.Enabled }}
  minIO:
    enabled: {{ $tpa.Enabled }}
  openshiftGitOps:
    enabled: {{ $gitops.Enabled }}
    config:
      argoCDClusterNamespace: {{ $argoCDNamespace }}
  openshiftKeycloak:
    enabled: {{ $keycloak.Enabled }}
    operatorGroup:
      targetNamespaces:
        - {{ default "empty" $keycloak.Namespace }}
  openshiftPipelines:
    enabled: {{ $pipelines.Enabled }}
  openshiftTrustedArtifactSigner:
    enabled: {{ $tas.Enabled }}
  redHatAdvancedClusterSecurity:
    enabled: {{ $acs.Enabled }}
  redHatDeveloperHub:
    enabled: {{ $rhdh.Enabled }}
  redHatQuay:
    enabled: {{ $quay.Enabled }}

#
# rhtap-infrastructure
#

{{- $tpaKafkaSecretName := "tpa-kafka" }}
{{- $tpaKafkaBootstrapServers := "tpa-kafka-bootstrap:9092" }}
{{- $tpaMinIORootSecretName := "tpa-minio-root-env" }}

{{- $quayMinIOSecretName := "quay-minio-root-user"  }}

infrastructure:
  kafkas:
    tpa:
      enabled: {{ $tpa.Enabled }}
      namespace: {{ $tpa.Namespace }}
      username: {{ $tpaKafkaSecretName }}
  minIOTentants:
    tpa:
      enabled: {{ $tpa.Enabled }}
      namespace: {{ $tpa.Namespace }}
      rootSecretName: {{ $tpaMinIORootSecretName }}
      kafkaNotify:
        bootstrapServers: {{ $tpaKafkaBootstrapServers }}
        username: {{ $tpaKafkaSecretName }}
        password:
          valueFrom:
            secretKeyRef:
              name: {{ $tpaKafkaSecretName }}
              key: password
    quay:
      enabled: {{ $quay.Enabled }}
      namespace: {{ $quay.Namespace }}
      rootSecretName: {{ $quayMinIOSecretName }}
      kafkaNotify:
        enabled: false
  postgresClusters:
    keycloak:
      enabled: {{ $keycloak.Enabled }}
      namespace: {{ $keycloak.Namespace }}
    guac:
      enabled: {{ $tpa.Enabled }}
      namespace: {{ $tpa.Namespace }}
  openShiftPipelines:
    enabled: {{ $rhdh.Enabled }}
    patchClusterTektonConfig:
      annotations:
        meta.helm.sh/release-name: rhtap-backing-services
        meta.helm.sh/release-namespace: {{ $argoCDNamespace }}
      labels:
        app.kubernetes.io/managed-by: Helm

#
# rhtap-backing-services
#

{{- $keycloakRouteTLSSecretName := "keycloak-tls" }}
{{- $keycloakRouteHost := printf "sso.%s" $ingressDomain }}
{{- $argoCDName := "argocd" }}
{{- $quayMinIOHost := printf "minio.%s.svc.cluster.local" $quay.Namespace }}

backingServices:
  keycloak:
    enabled: {{ $keycloak.Enabled }}
    namespace: {{ $keycloak.Namespace }}
    instances: 1
    database:
      host: keycloak-primary
      name: keycloak
      secretName: keycloak-pguser-keycloak
    route:
      host: {{ $keycloakRouteHost }}
      tls:
        enabled: {{ not $crc.Enabled }}
        secretName: {{ $keycloakRouteTLSSecretName }}
        termination: reencrypt
{{- if $crc.Enabled }}
      annotations:
        route.openshift.io/termination: reencrypt
{{- end }}
    service:
      annotations:
        service.beta.openshift.io/serving-cert-secret-name: {{ $keycloakRouteTLSSecretName }}
  argoCD:
    enabled: {{ $rhdh.Enabled }}
    name: {{ $argoCDName }}
    namespace: {{ $argoCDNamespace }}
    # TODO: link this secret name with RHDH configuration.
    secretName: rhtap-argocd-integration
    ingressDomain: {{ $ingressDomain }}
  acs:
    enabled: {{ $acs.Enabled }}
    namespace: {{ $acs.Namespace }}
    name: stackrox-central-services
    ingressDomain: {{ $ingressDomain }}
    integrationSecret:
      namespace: {{ .Installer.Namespace }}
  quay:
    enabled: {{ $quay.Enabled }}
    namespace: {{ $quay.Namespace }}
    config:
      radosGWStorage:
        enabled: true
        hostname: {{ $quayMinIOHost }}
        credentials:
          secretName: {{ $quayMinIOSecretName }}
    replicas:
      quay: 1
      clair: 1
#
# rhtap-integrations
#

# integrations:
#   acs:
#     endpoint: ""
#     token: ""
#   github:
#     clientId: ""
#     clientSecret: ""
#     id: ""
#     publicKey: |
#       -----BEGIN RSA PRIVATE KEY-----   # notsecret
#       -----END RSA PRIVATE KEY-----     # notsecret
#     token: ""
#     webhookSecret: ""
#   gitlab:
#     token: ""
#   quay:
#     dockerconfigjson: |
#       {
#       }
#     token: ""

#
# rhtap-dh
#

{{- $catalogURL := required "Red Hat Developer Hub Catalog URL is required"
    .Installer.Features.redHatDeveloperHub.Properties.catalogURL }}

developerHub:
  ingressDomain: {{ $ingressDomain }}
  catalogURL: {{ $catalogURL }}

#
# rhtap-tpa
#

{{- $tpaAppDomain := printf "-%s.%s" $tpa.Namespace $ingressDomain }}
{{- $tpaGUACDatabaseSecretName := "guac-pguser-guac" }}
{{- $tpaOIDCClientsSecretName := "tpa-realm-chicken-clients" }}
{{- $tpaTestingUsersEnabled := false }}
{{- $tpaRealmPath := "realms/chicken" }}
{{- $protocol := "https" -}}
{{- if $crc.Enabled }}
  {{- $protocol = "http" }}
{{- end }}

trustedProfileAnalyzer:
  enabled: {{ $tpa.Enabled }}
  appDomain: "{{ $tpaAppDomain }}"
  keycloakRealmImport:
    enabled: {{ $keycloak.Enabled }}
    keycloakCR:
      namespace: {{ $keycloak.Namespace }}
      name: keycloak
    oidcClientsSecretName: {{ $tpaOIDCClientsSecretName }}
    clients:
      walker:
        enabled: true
      testingManager:
        enabled: {{ $tpaTestingUsersEnabled }}
      testingUser:
        enabled: {{ $tpaTestingUsersEnabled }}
    frontendRedirectUris:
      - "http://localhost:8080"
{{- range list "console" "sbom" "vex" }}
      - "{{ printf "%s://%s-%s.%s" $protocol . $tpa.Namespace $ingressDomain }}"
      - "{{ printf "%s://%s-%s.%s/*" $protocol . $tpa.Namespace $ingressDomain }}"
{{- end }}

redhat-trusted-profile-analyzer:
  appDomain: "{{ $tpaAppDomain }}"
  ingress: &tpaIngress
    className: openshift-default
  openshift: &tpaOpenShift
    # In practice it toggles "https" vs. "http" for TPA components, for CRC it's
    # easier to focus on "http" communication only.
    useServiceCa: {{ not $crc.Enabled }}
  guac: &tpaGUAC
    database: &guacDatabase
      name:
        valueFrom:
          secretKeyRef:
            name: {{ $tpaGUACDatabaseSecretName }}
      host:
        valueFrom:
          secretKeyRef:
            name: {{ $tpaGUACDatabaseSecretName }}
      port:
        valueFrom:
          secretKeyRef:
            name: {{ $tpaGUACDatabaseSecretName}}
      username:
        valueFrom:
          secretKeyRef:
            name: {{ $tpaGUACDatabaseSecretName }}
      password:
        valueFrom:
          secretKeyRef:
            name: {{ $tpaGUACDatabaseSecretName }}
    initDatabase: *guacDatabase
  storage: &tpaStorage
    endpoint: {{ printf "http://minio.%s.svc.cluster.local:80" $tpa.Namespace }}
    accessKey:
      valueFrom:
        secretKeyRef:
          name: {{ $tpaMinIORootSecretName }}
    secretKey:
      valueFrom:
        secretKeyRef:
          name: {{ $tpaMinIORootSecretName }}
  eventBus:
    bootstrapServers: {{ $tpaKafkaBootstrapServers }}
    config:
      username: {{ $tpaKafkaSecretName }}
      password:
        valueFrom:
          secretKeyRef:
            name: {{ $tpaKafkaSecretName }}
  oidc: &tpaOIDC
{{- if $crc.Enabled }}
    issuerUrl: {{ printf "http://%s/%s" $keycloakRouteHost $tpaRealmPath }}
{{- else }}
    issuerUrl: {{ printf "https://%s/%s" $keycloakRouteHost $tpaRealmPath }}
{{- end }}
    clients:
      walker:
        clientSecret:
          valueFrom:
            secretKeyRef:
              name: {{ $tpaOIDCClientsSecretName }}
              key: walker
{{- if $tpaTestingUsersEnabled }}
      testingUser:
        clientSecret:
          valueFrom:
            secretKeyRef:
              name: {{ $tpaOIDCClientsSecretName }}
              key: testingUser
      testingManager:
        clientSecret:
          valueFrom:
            secretKeyRef:
              name: {{ $tpaOIDCClientsSecretName }}
              key: testingManager
{{- end }}

trustification:
  appDomain: "{{ $tpaAppDomain }}"
  openshift: *tpaOpenShift
  storage: *tpaStorage
  oidc: *tpaOIDC
  guac: *tpaGUAC
  ingress: *tpaIngress
  tls:
    serviceEnabled: "{{ not $crc.Enabled }}"

#
# rhtap-tas
#

{{- $tasRealmPath := "realms/trusted-artifact-signer" }}

trustedArtifactSigner:
  enabled: {{ $tas.Enabled }}
  ingressDomain: "{{ $ingressDomain }}"
  keycloakRealmImport:
    enabled: {{ $keycloak.Enabled }}
    keycloakCR:
      namespace: {{ $keycloak.Namespace }}
      name: keycloak
  secureSign:
    enabled: {{ $tas.Enabled }}
    namespace: {{ $tas.Namespace }}
    fulcio:
      oidc:
        clientID: trusted-artifact-signer
{{- if $crc.Enabled }}
        issuerURL: {{ printf "http://%s/%s" $keycloakRouteHost $tasRealmPath }}
{{- else }}
        issuerURL: {{ printf "https://%s/%s" $keycloakRouteHost $tasRealmPath }}
{{- end }}
      certificate:
        # TODO: promopt the user for organization email/name input!
        organizationEmail: trusted-artifact-signer@company.dev
        organizationName: RHTAP
