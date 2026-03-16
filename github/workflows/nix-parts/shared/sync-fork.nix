# Generates workflow for rebasing a fork over upstream changes.
# Uses rebase (not merge) to keep history clean.
# Requires the repo to be a fork (has a parent on GitHub).
{
  standalone = true;

  name = "Sync Fork (Rebase)";
  on = {
    schedule = [
      { cron = "0 4 * * *"; } # daily at 4am UTC
    ];
    workflow_dispatch = { };
  };
  permissions = {
    contents = "write";
  };
  jobs = {
    sync = {
      runs-on = "ubuntu-latest";
      steps = [
        {
          name = "Get upstream repo URL";
          id = "upstream";
          uses = "actions/github-script@v7";
          "with" = {
            script = ''
              const repo = await github.rest.repos.get({
                owner: context.repo.owner,
                repo: context.repo.repo,
              });
              if (!repo.data.fork || !repo.data.parent) {
                core.setFailed('This repository is not a fork');
                return;
              }
              const parent = repo.data.parent;
              core.setOutput('clone_url', parent.clone_url);
              core.setOutput('default_branch', parent.default_branch);
              core.info(`Upstream: ${"$"}{parent.full_name}, branch: ${"$"}{parent.default_branch}`);
            '';
          };
        }
        {
          name = "Checkout";
          uses = "actions/checkout@v4";
          "with" = {
            fetch-depth = 0;
            token = "\${{ secrets.GITHUB_TOKEN }}";
          };
        }
        {
          name = "Rebase over upstream";
          run = ''
            git config user.name "github-actions[bot]"
            git config user.email "github-actions[bot]@users.noreply.github.com"

            upstream_branch="${"$"}{{ steps.upstream.outputs.default_branch }}"
            our_branch="${"$"}{{ github.event.repository.default_branch }}"

            git remote add upstream "${"$"}{{ steps.upstream.outputs.clone_url }}"
            git fetch upstream "$upstream_branch"

            git checkout "$our_branch"
            git rebase "upstream/$upstream_branch"
            git push --force-with-lease origin "$our_branch"
          '';
        }
      ];
    };
  };
}
