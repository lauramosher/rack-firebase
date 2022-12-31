# Rack Firebase Middleware

[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](code_of_conduct.md) [![Gem Version](https://badge.fury.io/rb/rack-firebase.svg)](https://rubygems.org/gems/rack-firebase)


A rack middleware for verifying ID tokens from Google's Firebase. It provides token decoding and verification using [Firebase's 3rd Party Verification constraints](https://firebase.google.com/docs/auth/admin/verify-id-tokens?hl=en&authuser=3#verify_id_tokens_using_a_third-party_jwt_library).

## Installation

Add the gem to your Gemfile:

```ruby
gem "rack-firebase"
```

And execute

    $ bundle

Or, install it yourself:

    $ gem install rack-firebase

## Configuration

Configure your Firebase Project ID(s):

```ruby
Rack::Firebase.configure do |config|
  config.project_ids = ["your-project-id"]
end
```

Add the middleware to your rack application:

```ruby
use Rack::Firebase::Middleware
```

Now, all incoming requests will require a verified Firebase token.

## Usage

While just adding the middleware to your app will *block* requests without a verified token, your app will still need to handle the connection between the token and the subject in your application.

In order to facilitate this, the Subject claim (Device or User UID) is added to the request env before yielding to your app layer.

For example, assuming your User's model has a `uid` attribute for storing Firebase UID's:

```ruby
def current_user
  return @current_user if defined? @current_user

  uid = request.env[Rack::Firebase::Middleware::USER_UID]
  if uid
    @current_user = User.find_by(uid: uid)
  end
end

def user_signed_in?
  current_user.present?
end

def authenticate_user!
  unless user_signed_in?
    # deny access and abort request from application layer.
  end
end
```

From here, you can invoke `authenticate_user!` to ensure the token subject is actually a user in your application and use `current_user` to scope your requests or handle more granular authorization.

## Contributing

Bug reports and pull requests are welcome on GitHub.

This project is intended to be a safe, welcoming space for collaboration. All contributors are expected to adhere to the [Contributor Covenant](https://www.contributor-covenant.org) Code of Conduct.

## License

This gem is available as open source under the terms of the [MIT License](LICENSE).
