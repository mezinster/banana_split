import Vue from "vue";

// @ts-ignore
import VueQriously from "vue-qriously";
Vue.use(VueQriously);

// @ts-ignore
import QrcodeStream from "vue-qrcode-reader";
Vue.use(QrcodeStream);

import App from "./App.vue";
import router from "./router";
import i18n from "./i18n";

Vue.config.productionTip = false;

Vue.prototype.$eventHub = new Vue();

new Vue({
  router,
  i18n,
  render: function(h) {
    return h(App);
  }
}).$mount("#app");
