module RedisCounters
  module Dumpers
    module Dsl
      # Базовый класс для создания DSL к другим классам.
      # Класс обертка, который имеет все свойства, включая callbacks,
      # который просто настраивает целевой класс через его стандартные свойства.
      # Профит в простоте реализации DSL, в его изоляции от основного класса,
      # в разделении логики основного класса и DSL к нему.
      class Base
        attr_accessor :target

        class << self
          def setter(*method_names)
            method_names.each do |name|
              send :define_method, name do |data|
                target.send "#{name}=".to_sym, data
              end
            end
          end

          def varags_setter(*method_names)
            method_names.each do |name|
              send :define_method, name do |*data|
                target.send "#{name}=".to_sym, data.flatten
              end
            end
          end

          def callback_setter(*method_names)
            method_names.each do |name|
              send :define_method, name do |method = nil, &block|
                target.send "#{name}=".to_sym, method, &block
              end
            end
          end
        end

        def initialize(target, &block)
          @target = target
          instance_eval(&block)
        end
      end
    end
  end
end
