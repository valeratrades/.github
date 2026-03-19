# .github

Community health files and best practices for [valeratrades](https://github.com/valeratrades) repositories.

## best_practices/

Guidelines and standards used across projects. See [best_practices/README.md](./best_practices/README.md).

## Nix components

Reusable Nix modules for project configuration have moved to [v_flakes](https://github.com/valeratrades/v_flakes).

Update your flake inputs:
```nix
# before
v-utils.url = "github:valeratrades/.github?ref=v1.4";

# after
v-utils.url = "github:valeratrades/v_flakes";
```

#### License

<sup>
Licensed under <a href="LICENSE">Blue Oak 1.0.0</a>
</sup>
