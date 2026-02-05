# CodeName : LockDown Protocol

The goal of this project is to writedown one of my sleepless night thinking

There will be multiple step and approach on what can be done to tighten the security approach

The main goal is to secure the Development environment made with Eclipse Che but can be extended in the futur.

## Tool

- Mutating Webhook
    - Kyverno
    - Home Made hook for more complexe rull
- eBPF security engine
    - Tetragon
    - KubeArmor
- Network Security
    - Kubernetes native Network policy
    - CiliumNetworkPolicy
- Siem ?
- Response engine or RESE : QuickFunction ? or an operator ?
- Auto cancel of possible credential existing inside of the WS ?

## Workspace ?

A workspace is a development environment describe by a `devfile` who is translated by Eclipse Che into a pod contianing some industrialisation and theIDE.

This is a pre-packaged linux environment that allow user to enjoy an imutable space with lots of easy to setup automation.

## Why ?

In the current landscape not taking into account a possible security issue would be dumb, here the goal is to let the dev work and protect him from himself or the other.

## How ?

Everything will run in the background and if an action that souldn't be done is detected we start the "LockDown Protocol" we don't stop the workspace has we want to be able to know what happen but we lock EVERYTHING to prevent any possible escape.

### First Step : DefCon 1 - LockDown

1. The security engine / Siem detect a need to lockdown the workspace and then call the RESE by adding a flag on top of the Namespace like `weebo-security: defcon-1`
2. The RESE will apply the defcon-1 answer:
    1. Network will be locked by the Network policy
    2. The eBPF layer will Lock everything inside the pod by denying everything even the delete
    3. A Mail will be sent to the pseudo "Soc" to alert of an incident appening linked to the log
    4. The webhook will deny any modification request in the namespace to prevent any possible change inside of it
    5. Backup of the PVC will be locked in order for it to not be deleted
3. The Soc will then be able to analyse what happened and prevent any security outcome

### Second Step : DefCon 2 - Analyse

The team can Unlock the Namespace for them, the RESE will allow action only to user with the right to do so

We may need to find tool to analyse the running process / network event before the lockdown and every deny since then

### Third Step : DefCon 3 - Reproduce

The user is allowed some action but the workspace can't access the outside, we can ask the user to reproduce what he has done in another Namespace by restoring a backup.

The new workspace need to be at least locked from the outside and most action should be denyed.

The existing one should can be opened little by little.

### Fourth Step : DefCon 4 - Protect

The user is mostly locked, he can only access predefined ressources and the security engine may deny some action, all credential should be short lived and rotated even more regularly.

### Fifth Step : DefCon 5 - Let It Live

The user is back to it's original Namespace and goes back to it's original daily life until we meet again.
