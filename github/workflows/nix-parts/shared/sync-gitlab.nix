# Generates workflow for syncing to a GitLab mirror
# Requires GITLAB_TOKEN secret in GitHub repo
mirrorBaseUrl:
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
            if [ -z "${"$"}{{ secrets.GITLAB_TOKEN }}" ]; then
              echo "::error::Missing required secret GITLAB_TOKEN for GitLab sync"
              echo ""
              echo "To configure:"
              echo "  1. Go to your GitLab account -> Settings -> Access Tokens"
              echo "  2. Create a token with 'write_repository' scope"
              echo "  3. In this GitHub repo, go to Settings -> Secrets and variables -> Actions"
              echo "  4. Add GITLAB_TOKEN with your GitLab access token"
              exit 1
            fi
          '';
        }
        {
          uses = "actions/checkout@v4";
          "with" = {
            fetch-depth = 0;
            lfs = true;
          };
        }
        {
          name = "Configure GitLab mirror settings";
          run = ''
            repo_name="''${GITHUB_REPOSITORY#*/}"
            mirror_url="${mirrorBaseUrl}/''${repo_name}.git"
            gitlab_host=$(echo "${mirrorBaseUrl}" | sed -E 's|https?://([^/]+).*|\1|')
            project_path=$(echo "${mirrorBaseUrl}/''${repo_name}" | sed -E 's|https?://[^/]+/(.+)|\1|' | sed 's|/|%2F|g')
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
            repo_name="''${GITHUB_REPOSITORY#*/}"
            mirror_url="${mirrorBaseUrl}/''${repo_name}.git"
            gitlab_host=$(echo "${mirrorBaseUrl}" | sed -E 's|https?://([^/]+).*|\1|')
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
            git remote add gitlab "''${mirror_url}"

            # Push LFS objects if repo uses LFS (no-op if not)
            if [ -f ".gitattributes" ] && grep -q "filter=lfs" .gitattributes; then
              git lfs push --all gitlab
            fi

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
