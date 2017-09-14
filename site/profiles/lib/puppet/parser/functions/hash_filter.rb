# hash_filter
#
# The purpose of this function is to 'filter' hashes so that the result only
# contains the specified desired key value pairs.
#
# It takes two arguments:
#
# Arg 0 - An itterable object (ie a hash or array) of hashes to be proccessed
# Arg 1 - An array of the keys that the output hashes should contain.
#
# The intended use case is to allow the 'create_resources' function to create
# form hashes that were initially intended to create other resources.
# e.g. to crate nagios service checks for applications from their application
# hashes.
#
# Written by Ben Fairless and Seb Weavers March 2017   

module Puppet::Parser::Functions
  newfunction(:hash_filter, :type => :rvalue) do |args|
    input = args[0]
    keys = args[1]

    # # Error if argument is not a hash
    raise Puppet::ParseError, "A hash must be provided" unless input.is_a?(Hash)
    # Error if second argument is not an an array
    raise Puppet::ParseError, "Unwanted key(s) must be provided" unless keys.is_a?(Array)

    # Create an empty hash to output
    output = {}

    input.each do |name,data|
      output[name] = {}
      keys.each do |key|
        output[name][key] = data[key]
      end
    end

    return output
  end
end
