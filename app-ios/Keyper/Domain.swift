/// This deployment's domain constant (SPEC.md), the same 32 bytes as the Android app's Domain.kt:
/// both apps must derive the same phrases. It keys every derivation, so that the same sentence
/// gives different phrases in different deployments. It is public as soon as the app is
/// distributed, so it is not a secret and adds no secret entropy.
///
/// Every phrase this app has ever produced depends on this value. Never change it once anyone has
/// used the app. DomainTests checks that it matches Domain.kt and has the domain ID A248-7EAB.
let domainHex = "7bfe98b7ca068c4945be987523851e47faaa83670160ba38c8bb7e9e5e03c98f"
