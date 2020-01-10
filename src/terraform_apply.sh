#!/bin/bash

function terraformApply {
  # Gather the output of `terraform apply`.
  echo "apply: info: applying Terraform configuration in ${tfWorkingDir}"
  applyOutput=$(terraform apply -auto-approve -input=false ${*} 2>&1)
  applyExitCode=${?}
  applyCommentStatus="Failed"

  # Exit code of 0 indicates success. Print the output and exit.
  if [ ${applyExitCode} -eq 0 ]; then
    echo "apply: info: successfully applied Terraform configuration in ${tfWorkingDir}"
    echo "${applyOutput}"
    echo
    applyCommentStatus="Success"
  fi

  # Exit code of !0 indicates failure.
  if [ ${applyExitCode} -ne 0 ]; then
    echo "apply: error: failed to apply Terraform configuration in ${tfWorkingDir}"
    echo "${applyOutput}"
    echo
  fi

  # Comment on the pull request if necessary.
      OUTPUT="\`\`\`
${applyOutput}
\`\`\`"
  if [[ "${tfHideOutputInCommentDrawer}" == "1" ]]; then
      OUTPUT="<details><summary>Show Output</summary>
$OUTPUT
</details>"
  fi
  
  if [[ "$GITHUB_EVENT_NAME" == "pull_request" || "$GITHUB_EVENT_NAME" == "issue_comment" ]] && [ "${tfComment}" == "1" ]; then
    applyCommentWrapper="#### \`terraform apply\` ${applyCommentStatus} for \`${tfWorkingDir}\`
${tfCommentSubHeading}
${OUTPUT}
"

    applyCommentWrapper=$(stripColors "${applyCommentWrapper}")
    echo "apply: info: creating JSON"
    applyPayload=$(echo "${applyCommentWrapper}" | jq -R --slurp '{body: .}')
    applyCommentsURL=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)

    if [[ -z "$applyCommentsURL" || "$applyCommentsURL" == "null" ]]; then
      applyCommentsURL=$(cat ${GITHUB_EVENT_PATH} | jq -r .issue.comments_url)
    fi

    echo "apply: info: commenting on the pull request"
    echo "${applyPayload}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${applyCommentsURL}" > /dev/null
  fi

  exit ${applyExitCode}
}