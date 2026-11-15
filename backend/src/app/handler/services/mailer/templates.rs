//! Plantillas de los emails de MR nails (HTML con estilos en línea + texto plano).

use super::Email;

const BRAND: &str = "MR nails";

pub fn verify_email(nickname: &str, link: &str, hours: u64) -> Email {
    let name = escape(nickname);
    let link_html = escape(link);
    Email {
        subject: format!("Confirma tu correo electrónico | {BRAND}"),
        html: layout(
            "Confirma tu correo electrónico",
            &format!(
                "<p>Hola {name},</p>\
                 <p>Gracias por crear tu cuenta en {BRAND}. Para activarla y empezar a reservar tus citas, \
                 confirma tu dirección de correo electrónico.</p>\
                 {button}\
                 <p>Este enlace es válido durante {hours} horas.</p>\
                 {fallback}\
                 <p>Si no creaste una cuenta en {BRAND}, puedes ignorar este mensaje.</p>",
                button = button("Confirmar correo", &link_html),
                fallback = fallback(&link_html),
            ),
        ),
        text: format!(
            "Hola {nickname},\n\n\
             Gracias por crear tu cuenta en {BRAND}. Para activarla, confirma tu correo en este enlace:\n\n\
             {link}\n\n\
             El enlace es válido durante {hours} horas.\n\n\
             Si no creaste una cuenta en {BRAND}, puedes ignorar este mensaje.\n\n\
             {BRAND}"
        ),
    }
}

pub fn reset_password(nickname: &str, link: &str, minutes: u64) -> Email {
    let name = escape(nickname);
    let link_html = escape(link);
    Email {
        subject: format!("Restablece tu contraseña | {BRAND}"),
        html: layout(
            "Restablece tu contraseña",
            &format!(
                "<p>Hola {name},</p>\
                 <p>Recibimos una solicitud para restablecer la contraseña de tu cuenta en {BRAND}.</p>\
                 {button}\
                 <p>Este enlace es válido durante {minutes} minutos y solo puede usarse una vez.</p>\
                 {fallback}\
                 <p>Si no solicitaste este cambio, ignora este mensaje: tu contraseña actual seguirá funcionando.</p>",
                button = button("Restablecer contraseña", &link_html),
                fallback = fallback(&link_html),
            ),
        ),
        text: format!(
            "Hola {nickname},\n\n\
             Recibimos una solicitud para restablecer la contraseña de tu cuenta en {BRAND}.\n\
             Puedes crear una nueva en este enlace:\n\n\
             {link}\n\n\
             El enlace es válido durante {minutes} minutos y solo puede usarse una vez.\n\n\
             Si no solicitaste este cambio, ignora este mensaje: tu contraseña actual seguirá funcionando.\n\n\
             {BRAND}"
        ),
    }
}

pub fn second_factor(nickname: &str, code: &str, minutes: u64) -> Email {
    let name = escape(nickname);
    Email {
        subject: format!("Tu código de verificación: {code} | {BRAND}"),
        html: layout(
            "Código de verificación",
            &format!(
                "<p>Hola {name},</p>\
                 <p>Usa el siguiente código para completar la verificación en {BRAND}:</p>\
                 <p style=\"margin:28px 0;text-align:center;\">\
                   <span style=\"display:inline-block;padding:14px 28px;border-radius:8px;background:#f8eef1;\
                   color:#2b2b2b;font-size:30px;font-weight:700;letter-spacing:8px;font-family:Consolas,Menlo,monospace;\">{code}</span>\
                 </p>\
                 <p>El código es válido durante {minutes} minutos. No lo compartas con nadie: \
                 el equipo de {BRAND} nunca te lo pedirá.</p>\
                 <p>Si no intentaste iniciar sesión, te recomendamos cambiar tu contraseña.</p>"
            ),
        ),
        text: format!(
            "Hola {nickname},\n\n\
             Tu código de verificación de {BRAND} es: {code}\n\n\
             Es válido durante {minutes} minutos. No lo compartas con nadie: el equipo de {BRAND} nunca te lo pedirá.\n\n\
             Si no intentaste iniciar sesión, te recomendamos cambiar tu contraseña.\n\n\
             {BRAND}"
        ),
    }
}

// ===============================================================================
// Layout
// ===============================================================================

fn layout(title: &str, body: &str) -> String {
    format!(
        "<!doctype html>\
<html lang=\"es\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">\
<title>{title}</title></head>\
<body style=\"margin:0;padding:0;background:#f4f1f2;\">\
<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" style=\"background:#f4f1f2;padding:32px 16px;\">\
<tr><td align=\"center\">\
<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" style=\"max-width:560px;background:#ffffff;border-radius:12px;overflow:hidden;\">\
<tr><td style=\"background:#b03a5b;padding:24px 32px;text-align:center;\">\
<span style=\"color:#ffffff;font-family:Georgia,'Times New Roman',serif;font-size:26px;letter-spacing:1px;\">{BRAND}</span>\
</td></tr>\
<tr><td style=\"padding:32px;font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.6;color:#3a3a3a;\">\
<h1 style=\"margin:0 0 20px;font-size:20px;color:#2b2b2b;\">{title}</h1>\
{body}\
<p style=\"margin-top:28px;\">Saludos,<br>El equipo de {BRAND}</p>\
</td></tr>\
<tr><td style=\"padding:20px 32px;background:#faf7f8;font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:1.5;color:#8a8a8a;text-align:center;\">\
Este es un mensaje automático, por favor no respondas a este correo.<br>© {BRAND}\
</td></tr>\
</table></td></tr></table></body></html>"
    )
}

fn button(label: &str, href: &str) -> String {
    format!(
        "<p style=\"margin:28px 0;text-align:center;\">\
<a href=\"{href}\" style=\"display:inline-block;padding:13px 30px;border-radius:8px;background:#b03a5b;\
color:#ffffff;text-decoration:none;font-weight:700;font-size:15px;\">{label}</a></p>"
    )
}

fn fallback(href: &str) -> String {
    format!(
        "<p style=\"font-size:13px;color:#6f6f6f;\">Si el botón no funciona, copia y pega este enlace en tu navegador:<br>\
<a href=\"{href}\" style=\"color:#b03a5b;word-break:break-all;\">{href}</a></p>"
    )
}

/// Escapa texto del usuario (ej. el nickname) antes de meterlo en el HTML.
fn escape(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            '\'' => out.push_str("&#39;"),
            _ => out.push(c),
        }
    }
    out
}
