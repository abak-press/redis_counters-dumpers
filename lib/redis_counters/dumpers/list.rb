# coding: utf-8
require 'active_support/core_ext/hash/indifferent_access'
require_relative 'dsl/list'

module RedisCounters
  module Dumpers
    class List
      include ::RedisCounters::Dumpers::Dsl::List

      attr_accessor :dumpers

      def initialize
        @dumpers = HashWithIndifferentAccess.new
      end
    end
  end
end
