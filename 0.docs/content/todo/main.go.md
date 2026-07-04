# Change main.go

turn the confi into object
						"content": fmt.Sprintf(`apiVersion: apiserver.config.k8s.io/v1beta1
kind: AuthenticationConfiguration
jwt:
  - issuer:
      url: '%s'
      audiences:
        - '%s'
      audienceMatchPolicy: MatchAny
      certificateAuthority: "%s"
    claimValidationRules:
      - expression: "claims.email_verified == true"
        message: "email must be verified"
    claimMappings:
      username:
        expression: '"labsso:" + claims.email'
      groups:
        claim: "groups"
        prefix: "labsso:"
      uid:
        expression: "claims.sub"
    userValidationRules:
      - expression: "!user.username.startsWith('system:')"
        message: "username cannot used reserved system: prefix"
      - expression: "user.groups.all(group, !group.startsWith('system:'))"
        message: "groups cannot used reserved system: prefix"`, oidcIssuerUrl, oidcClientID, oidcCert),
					},
				}