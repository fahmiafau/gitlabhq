(() => {
  JumpToDiscussion = Vue.extend({
    props: {
      discussionId: String
    },
    data: function () {
      return {
        discussions: CommentsStore.state,
      };
    },
    computed: {
      allResolved: function () {
        const discussion = this.discussions[discussionId];
        return discussion.isResolved();
      }
    },
    methods: {
      jumpToNextUnresolvedDiscussion: function () {
        let nextUnresolvedDiscussionId,
            firstUnresolvedDiscussionId;

        if (!this.discussionId) {
          let i = 0;
          for (const discussionId in this.discussions) {
            const discussion = this.discussions[discussionId];
            const isResolved = discussion.isResolved();

            if (!firstUnresolvedDiscussionId && !isResolved) {
              firstUnresolvedDiscussionId = discussionId;
            }

            if (!isResolved) {
              nextUnresolvedDiscussionId = discussionId;
              break;
            }

            i++;
          }
        } else {
          const discussionKeys = Object.keys(this.discussions),
                indexOfDiscussion = discussionKeys.indexOf(this.discussionId),
                nextDiscussionId = discussionKeys[indexOfDiscussion + 1];

          if (nextDiscussionId) {
            nextUnresolvedDiscussionId = nextDiscussionId;
          } else {
            firstUnresolvedDiscussionId = discussionKeys[0];
          }
        }

        if (firstUnresolvedDiscussionId) {
          // Jump to first unresolved discussion
          nextUnresolvedDiscussionId = firstUnresolvedDiscussionId;
        }

        if (nextUnresolvedDiscussionId) {
          $.scrollTo(`.discussion[data-discussion-id="${nextUnresolvedDiscussionId}"]`, {
            offset: -($('.navbar-gitlab').outerHeight() + $('.layout-nav').outerHeight())
          });
        }
      }
    }
  });

  Vue.component('jump-to-discussion', JumpToDiscussion);
})();
