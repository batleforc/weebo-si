# Security in Eclipse Che (Kubernetes Environments)

This project aims to work on various security aspects within Eclipse Che and Kubernetes environments with a special focus on:

- Securing cluster access (RBAC, OIDC)
- Network security (Network Policies)
- Pod and process security (Auditing, Pod Security Standards)
- Secrets management (Kubernetes Secrets, external secret management solutions)
- Compliance and best practices (CIS Benchmarks, Security audits)
- Automation of security answers and remediation (Network Isolation, Vulnerability Scanning)

## Scenarios

We will explore and implements security measures from the creation of a Git Project to the building of the application:

1. **Cluster Access Security**: Implement RBAC policies and OIDC authentication for secure access to the Kubernetes cluster.
2. **Network Security**: Define and enforce Network Policies to restrict traffic between pods and services.
   1. **Isolate Che Workspaces**: Ensure that each Che workspace is isolated from others using Network Policies.
   2. **Restrict External Access**: Limit access to external services from within the cluster (Setup of Cache for certain resources ?).
3. **Pod and Process Security**: Enable auditing and enforce Pod Security Standards to ensure that pods run with the least privileges necessary.
   1. **Audit Workspace Activities**: Monitor and log activities within Che workspaces for security auditing (e.g., Falco, KubeArmor, Tetragon).
   2. **Enforce Pod Security Standards**: Ensure that Che workspaces comply with Pod Security Standards (e.g., restrict privileged containers, enforce read-only root filesystems).
   3. **Restrict Image Sources**: Limit the sources from which container images can be pulled to trusted registries.
   4. **Limit Workspace Capabilities**: Restrict the capabilities of containers running in Che workspaces to minimize potential attack vectors.
   5. **Control Resource Usage**: Implement resource quotas and limits to prevent denial-of-service attacks from within Che workspaces.
4. **Secrets Management**: Use Kubernetes Secrets and explore external secret management solutions to securely manage sensitive information.
   1. **Securely Store Git Credentials**: Use Kubernetes Secrets to store Git credentials securely for Che workspaces.
   2. **Store secret environment variables**: Manage environment variables inside "Vault" like solution to easen the development process.
5. **Compliance and Best Practices**: Implement CIS Benchmarks and conduct security audits to ensure compliance with best practices.
   1. **Setup CI/CD**: Integrate security checks into the CI/CD pipeline for Che workspaces.
6. **Automation of Security Responses and Remediation**: Automate responses to security incidents and remediation actions.
   1. **Automate Network Isolation**: Automatically apply Network Policies in response to detected threats.
   2. **Vulnerability Scanning**: Implement automated vulnerability scanning for container images used in Che workspaces.
   3. **Notification System**: Set up a notification system to alert administrators of security incidents.
   4. **Auto-Remediation**: Implement automated remediation actions for common security issues detected in Che workspaces.
   5. **Integrate with SIEM**: Send security logs and alerts to a Security Information and Event Management (SIEM) system for centralized monitoring and analysis.

## Technologies

- [Kubernetes](https://kubernetes.io/)
- [Eclipse Che](https://eclipse.dev/che/) => Cloud IDE on Kubernetes
- [Authentik](https://goauthentik.io/) => OIDC Provider
- [Backstage](https://backstage.io/) => Developer Portal
- [OpenBao](https://openbao.io/) => Vault alternative
- [Kyverno](https://kyverno.io/) => Kubernetes Native Policy Management
- [Falco](https://falco.org/) => Runtime Security
- [KubeArmor](https://github.com/kubearmor/KubeArmor) => Runtime Security
- [Tetragon](https://tetragon.io/) => Runtime Security
- [Trivy](https://trivy.dev/) => Vulnerability Scanning for Container Images
- [Cilium](https://cilium.io/) => Advanced Networking and Security

## Links

- [Eclipse Che Documentation](https://www.eclipse.org/che/docs/)
- [Falco x CRIU and OpenFaaS](https://blog.fraktal.fi/navigating-kubernetes-incident-response-with-falco-criu-and-openfaas-285021bbdbe4)
- [Setup Kubearmor](https://medium.com/@ikbenezer/protecting-your-kubernetes-environment-with-kubearmor-6c728b3267e4)
- [Falco setup and sidekick](https://rm3a.fr/guide-pratique-falco-sidekick-installation-et-configuration-complete/?srsltid=AfmBOor_HSlAAte9NMDsNhq639opCK582Ew-8IOmX9rID6xcx6iCQiaj)
- [Cilium Network Policies editor](https://editor.networkpolicy.io/)