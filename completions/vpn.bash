_vpn_completion() {
    local cur prev words cword
    _init_completion || return

    local commands="ip web ssh list list-details details set-psk"

    # Helper function to get device list
    _vpn_devices() {
        vpn list 2>/dev/null
    }

    case "${cword}" in
        1)
            # Complete main commands
            COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
            ;;
        2)
            # Complete based on previous command
            case "${prev}" in
                ip|web|details)
                    # Complete with device hostnames
                    COMPREPLY=($(compgen -W "$(_vpn_devices)" -- "${cur}"))
                    ;;
                ssh)
                    # For ssh, second argument is user - offer common usernames
                    COMPREPLY=($(compgen -u -- "${cur}"))
                    ;;
                set-psk)
                    # No completion for PSK/API args
                    ;;
            esac
            ;;
        3)
            # For ssh command, third argument is hostname
            if [[ "${words[1]}" == "ssh" ]]; then
                COMPREPLY=($(compgen -W "$(_vpn_devices)" -- "${cur}"))
            elif [[ "${words[1]}" == "set-psk" ]]; then
                COMPREPLY=()
            fi
            ;;
    esac
}

complete -F _vpn_completion vpn
