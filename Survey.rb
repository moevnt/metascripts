module Msf
    ##
    # Runs the standard host survey on the current session
    ##

    class Plugin::survey < Msf::Plugin

        class ConsoleCommandDispatcher
            include Msf::Ui::Console::CommandDispatcher

            class CaptureJobListener
                def initialiaze (name, done_event, dispatcher)
                    @name = name
                    @done_event = done_event
                    @dispatcher = dispatcher
                end
                
                def waiting(_id)
                    self.succeeded = true
                    @dispatcher.print_good("#{@name} started")
                    @done_event.set
                end

                def start(id); end

                def completed(id, result, mod); end

                def failed(_id, _error, _mod)
                    @dispatcher.print_error("#{@name} failed to start")
                    @done_event.set
                end

                attr_accessor :succeeded
            end

            HELP_REGEX = /^-?-h(?:elp)?$/.freeze

            def name
                'Host Survey'
            end

            def commands
                {
                    'survey' => 'Begin suvery on active session'
                }
            end

            def cmd_captureg(*args)
                begin
                    if args.first == 'stop'
                        listeners_stop(args)
                        return
                    end

                    if args.first == 'start'
                        listeners_start(args)
                        return
                    end
                    return help
                
                rescue ArgumentError => e
                    print_error(e.message)
                end
            end

            def listeners_start(args)
                config = parse_start_args(args)
                if config[:show_help]
                    help('start')
                    return
                end

                session = config[:session]
                if session.nil?
                    session = 'local'
                end

                if @active_jobs_ids.key?(session)
                    active_jobs = @active_jobs_ids[session]

                    active_jobs.each do |job_id|
                        next unless framework.jobs.key?(job_id.to_s)

                        session_str = ''
                        unless session.nil?
                            session_str = ' on this session'
                        end
                        print_error("A survey is already in progress#{session_str}. Stop the existing capture then restart a new one.")
                        return
                    end
                end

                if @active_loggers.key?(session)
                    logger = @active_loggers[session]
                    logger.close
                end

                @active_jobs_ids[session] = []
                @active_loggers.delete(session)

                transform_params(config)
                validate_params(config)

                modules = {
                    #capturing
                    'IP' => 'au'
                }


