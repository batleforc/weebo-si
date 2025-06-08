# Rust driven Wireguard X Chrome Workflow

Why the hell do i have this kind of idea right now ?

## GOAL

- One Packaged (?) chrome instance that with a wireguard can work has if it was directly in the target network
- Full User Namespace in order for it to not need Admin Right.
- Launched with TAURI !
- Should work either with an SSO Workflow or directly by injecting the wg0.conf

## Clue

- [Setup a Proxy in Chrome](https://stackoverflow.com/questions/75533339/how-do-i-set-up-a-proxy-server-using-chromiumoxide)
- [Wireguard UserNamespace in rust](https://github.com/cloudflare/boringtun)
- [Use Chrome in Rust](https://crates.io/crates/chromiumoxide)
- [Source of the idea](https://docs.netbird.io/how-to/netbird-on-faas)
- [Port Forward in rust](https://github.com/aramperes/onetun)

## Possible Wireguard Backend

- [NetBird](https://github.com/netbirdio/netbird) [NetBird TF](https://registry.terraform.io/providers/netbirdio/netbird/latest)
- [FireZone](https://github.com/firezone/firezone)
- [HeadScale](https://github.com/juanfont/headscale) [HeadScale TF](https://registry.terraform.io/providers/awlsring/headscale/latest/docs) [HeadScale Helm](https://artifacthub.io/packages/helm/gabe565/headscale) [Headscale Tasse de Café](https://une-tasse-de.cafe/blog/headscale-hybrid/)

### Pré-requis

- Self Hosted
- Wireguard
