Rails.application.config.session_store :cookie_store, key: "_acme_hr_session",
  same_site: :lax, httponly: true, secure: Rails.env.production?, expire_after: 8.hours
