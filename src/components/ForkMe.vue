<template>
  <a id="forkongithub" class="fork-link" :href="url" target="_blank" rel="noopener noreferrer">
    🥄&nbsp;{{ $t('forkMe') }}
  </a>
</template>

<script lang="ts">
export default {
  name: "ForkMe",
  props: {
    url: {
      type: String,
      required: true
    }
  }
};
</script>

<style>
.fork-link {
  font-size: 0.875rem;
  color: var(--text-secondary);
  text-decoration: none;
}
.fork-link:hover {
  color: var(--text);
  text-decoration: underline;
}
</style>
