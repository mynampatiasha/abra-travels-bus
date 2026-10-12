# WhatsApp connection and customer login OTP

In the management app, open Settings → WhatsApp.

- **WhatsApp Connection:** display phone number, WhatsApp Business Account (WABA) ID, Phone Number ID, webhook verify token, access token.
- **OTP Settings:** approved authentication template name, language code, and SMS fallback.
- **Notification Settings:** the separate template used for platform notifications.

Save the configuration, then use **Test connection** to check the saved sender credentials. This test does not send an OTP or verify template approval. The display phone number is a reference label; Meta sends using the Phone Number ID. Both tokens are encrypted, never returned by the API, and an empty token field keeps the saved token.

The webhook verify token is reserved for webhook setup. This form does not create a public webhook receiver or register a callback with Meta. It is not required to send login OTPs.

## Template to create in Meta

Create a template in the same WhatsApp Business account as the configured sender:

| Setting | Value |
|---|---|
| Name | `abra_travels_login_otp` |
| Category | Authentication |
| Language | English (US), API code `en_US` |
| OTP button | Copy code |
| Security recommendation | Enable |
| Expiration warning | 5 minutes only when the deployed `OTP_TTL_SECONDS` is 300; otherwise match the deployed lifetime or omit this optional warning |

Use Meta's authentication template text and OTP placeholder, rather than a custom marketing or utility message. The backend fills the code in the message body and copy-code button. Submit the template for approval; after approval, enter `abra_travels_login_otp` and `en_US` in OTP Settings and save.

The repository's example environment uses `OTP_TTL_SECONDS=300`. The expiry wording in Meta does not change server-side expiry.

Real delivery requires `WHATSAPP_PROVIDER=meta`, a configured Graph API version, valid sender credentials and an approved matching template. The development provider simulates delivery only.

Reference: [Meta's authentication template with Copy Code example](https://www.postman.com/meta/whatsapp-business-platform/request/6vkv46u/create-authentication-template-w-otp-copy-code-button).
