require "openssl"
require "rack/firebase"

puts "OpenSSL::VERSION: #{OpenSSL::VERSION}"
puts "OpenSSL::OPENSSL_VERSION: #{OpenSSL::OPENSSL_VERSION}"
puts "OpenSSL::OPENSSL_LIBRARY_VERSION: #{OpenSSL::OPENSSL_LIBRARY_VERSION}\n\n"

CERT_PATH = File.join(__dir__, "support", "fixtures", "certs")
