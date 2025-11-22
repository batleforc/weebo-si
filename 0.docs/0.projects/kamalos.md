# Kamalos

Le projet Kamalos a pour but de tester et expérimenter Kamaji en tant que control plane pour un cluster Talos. Cette XP est issue de la création du projet Github [Talos CSR Signer](https://github.com/clastix/talos-csr-signer) qui permet de gérer les CSR Talos via un sidecar dans le control plane Kamaji ainsi que de la vidéo [Kamaji x Talos](https://www.youtube.com/watch?v=nSGo_72LnmY) de la chaine YouTube Clastix.

Cette XP a commencer lors du stream du 15 Novembre 2025 et est toujours en cours. Le cadre de cette XP est le suivant:

- Un cluster Talos avec Kubevirt/Kamaji/Cluster API
- Un control plane Kamaji avec le sidecar Talos CSR Signer
- Des workers Talos sous forme de machines virtuelles Kubevirt OU un possible worker container (a tester)
- Tester si la Cluster API peut s'intégrer en l'état avec ce workflow
- Bien sur, valider l'usage de briques de base comme:
  - ArgoCD
  - Cilium
  - Grafana x Coroot
  - Kubevirt CSI
