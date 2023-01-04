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

### Testing

In order to test your authenticated routes, you'll need to provide a valid token in the authorization header.

Since Firebase typically issues signed tokens using their certificates, this can make it difficult to test your authenticated routes with valid tokens.

As such, some test helpers are provided to help faciliate automated testing.

> Note: For manual testing, it is recommended to create a test-specific user in your Firebase project and test the full authentication flow with your routes.

#### Mocking requests for public keys

There are two options for mocking the requests from Google; choose the one that best fits your testing library and needs:

1. Explicitly start and stop firebase mocks, or
2. Wrap each example that needs to be mocked.

```ruby
# Require the test helpers
require "rack/firebase/test_helpers"

describe "your request specs" do
  # Explicitly mock before/after
  before { Rack::Firebase::TestHelpers.mock_start }
  after { Rack::Firebase::TestHelpers.mock_end }

  # Or wrap each example
  # This is for RSpec only! Use setup/teardown or before/after with the explicit mock for Minitest.
  around(:example) do |example|
    Rack::Firebase::TestHelpers.mock_signature_verification do
      example.run
    end
  end
end
```

Optionally, you can pass minutes as a number to `mock_start` to overwrite when the cache key should be refreshed. By default, this is set to `5000`, or approximately 83 minutes.

#### Generating Tokens

A test helper is provided that will generate a valid token and add it to your request headers for your specs.

```ruby
# Require the test helpers
require "rack/firebase/test_helpers"

it "tests something" do
  user = fetch_user() # this presumes your user has a `uid`!
  headers = { "Accept" => "application/json", "Content-Type" => "application/json" }

  # This will generate a valid token and add it to your headers
  auth_headers = Rack::Firebase::TestHelpers.auth_headers(headers, user.uid)

  get "/", headers: auth_headers

  expect(last_response).to be_ok
end
```

##### Customizing

By default, the token will be created using the first project ID provided in your configuration. If your app is configured for multiple projects and you wish to test one of the other projects, you can optionally add the `aud` to the arguments:

```ruby
Rack::Firebase::TestHelpers.auth_headers(headers, user.uid, aud: "different-project")
```

There is a fourth arg that takes a hash of options that will let you alter the payload.

> Caution: it is possible for provided options to produce invalid tokens.

| argument | description | default |
| --- | --- | --- |
| email | User's email address used for authentication. Added to the payload as `email` and included in the array of email identities in `firebase.identities.email` | test@test.com |
| verified | Denotes if the email used to sign in is verified by the user | false |
| auth_time | The last authentication time recorded by Google | Current time |
| iat | Denotes the time the token was issued. When iat is provided, but not an auth time, the auth time is also set to the iat time. | Current time |
| exp | Denotes when the token expires | Current time + 5000 |

## Contributing

Bug reports and pull requests are welcome on GitHub.

This project is intended to be a safe, welcoming space for collaboration. All contributors are expected to adhere to the [Contributor Covenant](https://www.contributor-covenant.org) Code of Conduct.

## License

This gem is available as open source under the terms of the [MIT License](LICENSE).
