//= require ../services/approvals_api

(() => {
  let singleton;

  class ApprovalsStore {
    constructor(rootStore) {
      if (!singleton) {
        singleton = gl.ApprovalsStore = this;
        this.init(rootStore);
      }
      return singleton;
    }

    init(rootStore) {
      this.rootStore = rootStore;
      this.api = new gl.ApprovalsApi(rootStore.dataset.endpoint);
      this.state = {
        loading: false,
        loaded: false,
      };
    }

    assignToRootStore(data) {
      return this.rootStore.assignToData('approvals', data);
    }

    initStoreOnce() {
      const state = this.state;
      if (state.loading || state.loaded) {
        state.loading = true;
        this.fetch()
          .then(() => {
            state.loading = false;
            state.loaded = true;
          })
          .catch((err) => {
            console.error(`Failed to initialize approvals store: ${err}`);
          });
      }
      return this.fetch();
    }

    fetch() {
      return this.api.fetchApprovals()
        .then(res => this.assignToRootStore(res.data));
    }

    approve() {
      return this.api.approveMergeRequest()
        .then(res => this.assignToRootStore(res.data));
    }

    unapprove() {
      return this.api.unapproveMergeRequest()
        .then(res => this.assignToRootStore(res.data));
    }
  }

  gl.ApprovalsStore = ApprovalsStore;
})();

