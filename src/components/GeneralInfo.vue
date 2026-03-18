<template>
  <div class="general-info">
    <h2>{{ $t('infoWhatIsThis') }}</h2>
    <i18n path="infoWhatIsThisBody" tag="p">
      <template #link>
        <a href="https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing" target="_blank">
          {{ $t('infoShamirLink') }}
        </a>
      </template>
    </i18n>
    <h2>{{ $t('infoHowDoesItWork') }}</h2>
    <p>{{ $t('infoHowBody1') }}</p>
    <p>{{ $t('infoHowBody2') }}</p>
    <p>{{ $t('infoHowBody3') }}</p>
    <p>{{ $t('infoHowBody4') }}</p>
    <h2>{{ $t('infoHowToUse') }}</h2>
    <ol>
      <li>{{ $t('infoStep1') }}</li>
      <li>{{ $t('infoStep2') }}</li>
      <li>{{ $t('infoStep3') }}</li>
    </ol>
    <p>{{ $t('infoMinimalRisk') }}</p>
  </div>
</template>

<script lang="ts">
import Vue from "vue";

export default Vue.extend({
  name: "GeneralInfo",
});
</script>

<style>
.general-info {
  display: block;
  padding-bottom: 30px;
}
p {
  line-height: 1.5em;
}
li {
  padding-bottom: 0.5em;
}
</style>
