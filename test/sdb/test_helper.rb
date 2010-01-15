require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/right_aws'
require File.dirname(__FILE__) + '/../test_credentials'
TestCredentials.get_credentials
require 'sdb/active_sdb'
