package app.getkeyper

/**
 * This deployment's domain constant (SPEC.md): 32 random bytes that key every derivation, so
 * that the same sentence gives different phrases in different deployments. It is public as
 * soon as the APK is distributed, so it is not a secret and adds no secret entropy.
 *
 * Every phrase this app has ever produced depends on this value. Never change it once anyone
 * has used the app, and keep this file (or a released APK) safe: without it no phrase can be
 * regenerated. Anyone deploying their own Keyper replaces it with `openssl rand -hex 32`
 * before first use.
 */
internal const val DOMAIN_HEX = "7bfe98b7ca068c4945be987523851e47faaa83670160ba38c8bb7e9e5e03c98f"
