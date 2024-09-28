#!/usr/bin/env bash

main() {
    local name_of_iam_role="$1"
    [ -z "${name_of_iam_role}" ] && {
        echo "Usage: $0 <name_of_iam_role>"
        return 1
    }

    list_attached_role_policies "${name_of_iam_role}"

    return 0
}

list_attached_role_policies() {
    local role_name="$1"
    local policy_arn
    echo "RoleName: ${role_name}"
    while read policy_arn; do
        get_policy "${policy_arn}"
        echo
    done < <(aws iam list-attached-role-policies --role-name "${role_name}" | jq -r '.AttachedPolicies[].PolicyArn')
}

get_policy() {
    local policy_arn="$1"

    aws iam get-policy --policy-arn "${policy_arn}" | jq -r '.Policy | "    PolicyName -> " + .PolicyName + "\n    Arn -> " + .Arn + "\n    Description -> " + .Description'
}

main "$@"
