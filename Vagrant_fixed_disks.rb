# Module monkey-patch to clone the virtual disk to a fixed allocation
module DisksizeFixed
  class Plugin < Vagrant.plugin('2')
    name "disksizefixed"

    class Action
      def initialize(app, env)
        @app = app

        Vagrant::Disksize::Action::ResizeDisk.class_eval do
          def clone_as_vdi(driver, src, dst)
            driver.execute("clonemedium", src[:file], dst[:file], '--format', 'VDI', '--variant', 'Fixed')
          end
        end
      end

      def call(env)
        @app.call(env)
      end
    end

    action_hook(:disksizefixed, :machine_action_up) do |hook|
      hook.before(Vagrant::Disksize::Action::ResizeDisk, DisksizeFixed::Plugin::Action)
    end
  end
end

Vagrant.configure('2') do |config|
  # Resize the original box disk to the same size, but use the monkey
  # patch above to make it a fixed disk
  config.disksize.size = '64GB'
end
