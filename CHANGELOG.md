### What's changed in v1.0.0

* chore(deps): migrate workflows-crossplane to hops-ops@v3.2.0 (by @patrickleet)

* fix: emit GA external-dns annotations on exposure HTTPRoute (by @patrickleet)

  BREAKING CHANGE: * fix!: emit GA external-dns annotations on exposure HTTPRoute

  BREAKING CHANGE: hostname/target/ttl annotations move from
  external-dns.alpha.kubernetes.io/* to external-dns.kubernetes.io/*.
  Coordinate with aws-dns-stack / cloudflare-dns-stack GA majors.

  * test: expect GA external-dns annotations on exposure HTTPRoute


See full diff: [v0.2.1...v1.0.0](https://github.com/hops-ops/gitkb-stack/compare/v0.2.1...v1.0.0)
