{ gistId ? "b48e6f02c61942200e7d1e3eeabf9bcb" }:
{
  name = "Update LOC Badge";
  runs-on = "ubuntu-latest";
  steps = [
    {
      name = "Checkout repository";
      uses = "actions/checkout@v4";
    }
    {
      name = "Install tokei";
      run = "cargo install tokei";
    }
    {
      name = "Count lines of code";
      id = "count";
      run = ''
        # Extract repository name (e.g., "valeratrades/readme-fw" -> "readme-fw")
        PNAME="''${GITHUB_REPOSITORY##*/}"
        echo "pname=$PNAME" >> $GITHUB_OUTPUT

        LOC=$(tokei --output json | jq '.Total.code')
        echo "loc=$LOC" >> $GITHUB_OUTPUT
        echo "Lines of code for $PNAME: $LOC"

        # Generate JSON with project-specific filename
        echo "{\"schemaVersion\": 1, \"label\": \"LoC\", \"message\": \"$LOC\", \"color\": \"lightblue\"}" > ''${PNAME}-loc.json
      '';
    }
    {
      name = "Display generated JSON";
      run = "cat ${{ steps.count.outputs.pname }}-loc.json";
    }
    {
      name = "Update gist";
      uses = "exuanbo/actions-deploy-gist@v1";
      "with" = {
        token = "${{ secrets.GITHUB_LOC_GIST }}";
        gist_id = gistId;
        file_path = "${{ steps.count.outputs.pname }}-loc.json";
      };
    }
  ];
}
