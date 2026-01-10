# Generates workflow for syncing to a GitLab mirror
# Requires GITLAB_MIRROR_URL and GITLAB_TOKEN secrets in GitHub repo
{
  defaults ? false,
  default ? defaults,
}:
{
  standalone = true;

  name = "Sync to GitLab Mirror";
  on = {
    push = {
      branches = [ "**" ];
      tags = [ "**" ];
    };
    workflow_dispatch = { };
  };
  permissions = {
    contents = "read";
  };
  jobs = {
    other = {
      runs-on = "ubuntu-latest";
      steps = [
        {
          name = "Check required secrets";
          run = ''
            missing=""
            if [ -z "${"$"}{{ secrets.GITLAB_MIRROR_URL }}" ]; then
              missing="''${missing}  - GITLAB_MIRROR_URL: The GitLab repository URL (e.g., https://gitlab.com/username/repo.git)\n"
            fi
            if [ -z "${"$"}{{ secrets.GITLAB_TOKEN }}" ]; then
              missing="''${missing}  - GITLAB_TOKEN: A GitLab personal access token with write_repository scope\n"
            fi
            if [ -n "$missing" ]; then
              echo "::error::Missing required secrets for GitLab sync:"
              printf "$missing" >&2
              echo ""
              echo "To configure:"
              echo "  1. Go to your GitLab account -> Settings -> Access Tokens"
              echo "  2. Create a token with 'write_repository' scope"
              echo "  3. In this GitHub repo, go to Settings -> Secrets and variables -> Actions"
              echo "  4. Add GITLAB_MIRROR_URL (e.g., https://gitlab.com/username/repo.git)"
              echo "  5. Add GITLAB_TOKEN with your GitLab access token"
              exit 1
            fi
          '';
        }
        {
          uses = "actions/checkout@v4";
          "with" = {
            fetch-depth = 0;
          };
        }
        {
          name = "Configure GitLab mirror settings";
          run = ''
            # Extract project path from URL (e.g., "username/repo" from "https://gitlab.com/username/repo.git")
            gitlab_host=$(echo "${"$"}{{ secrets.GITLAB_MIRROR_URL }}" | sed -E 's|https?://([^/]+).*|\1|')
            project_path=$(echo "${"$"}{{ secrets.GITLAB_MIRROR_URL }}" | sed -E 's|https?://[^/]+/(.+)\.git|\1|' | sed 's|/|%2F|g')
            github_url="https://github.com/${"$"}{{ github.repository }}"

            # Disable issues, MRs, wiki, etc. and set description pointing to GitHub
            curl -s --request PUT \
              --header "PRIVATE-TOKEN: ${"$"}{{ secrets.GITLAB_TOKEN }}" \
              --header "Content-Type: application/json" \
              --data '{
                "issues_access_level": "disabled",
                "merge_requests_access_level": "disabled",
                "wiki_access_level": "disabled",
                "builds_access_level": "disabled",
                "snippets_access_level": "disabled",
                "description": "Mirror of '"''${github_url}"'. All development happens on GitHub."
              }' \
              "https://''${gitlab_host}/api/v4/projects/''${project_path}" > /dev/null
          '';
        }
        {
          name = "Push to GitLab mirror";
          run = ''
            # Extract host from URL for credential configuration
            gitlab_host=$(echo "${"$"}{{ secrets.GITLAB_MIRROR_URL }}" | sed -E 's|https?://([^/]+).*|\1|')
            github_url="https://github.com/${"$"}{{ github.repository }}"

            # Configure git credentials
            git config --global credential.helper store
            echo "https://oauth2:${"$"}{{ secrets.GITLAB_TOKEN }}@''${gitlab_host}" > ~/.git-credentials

            # Configure git user for the mirror commit
            git config user.email "github-actions[bot]@users.noreply.github.com"
            git config user.name "github-actions[bot]"

            # Add mirror notice to README if not already present
            if [ -f "README.md" ]; then
              if ! grep -q "This is a mirror" README.md; then
                # Prepend mirror notice
                {
                  echo '> [!NOTE]'
                  echo "> This is a mirror. Development happens on [GitHub](''${github_url})."
                  echo ""
                  cat README.md
                } > README.md.tmp && mv README.md.tmp README.md
                git add README.md
                git commit -m "chore: add mirror notice to README" --allow-empty || true
              fi
            fi

            # Add GitLab remote
            git remote add gitlab "${"$"}{{ secrets.GITLAB_MIRROR_URL }}"

            # Push all branches and tags
            git push gitlab --all --force
            git push gitlab --tags --force

            # Cleanup credentials
            rm -f ~/.git-credentials
          '';
        }
      ];
    };
  };
}
