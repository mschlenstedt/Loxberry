import { ZIndexUtils, DomHandler } from 'primevue/utils';
import { openBlock, createBlock, createVNode, mergeProps, renderSlot, createCommentVNode, Teleport, Transition, withCtx } from 'vue';

var script = {
    name: 'Image',
    inheritAttrs: false,
    props: {
        preview: {
            type: Boolean,
            default: false
        },
        class: null,
        style: null,
        imageStyle: null,
        imageClass: null
    },
    mask: null,
    data() {
        return {
            maskVisible: false,
            previewVisible: false,
            rotate: 0,
            scale: 1
        }
    },
    beforeUnmount() {
        if (this.mask) {
            ZIndexUtils.clear(this.container);
        }
    },
    methods: {
        maskRef(el) {
            this.mask = el;
        },
        toolbarRef(el) {
            this.toolbarRef = el;
        },
        onImageClick() {
            if (this.preview) {
                this.maskVisible = true;
                setTimeout(() => {
                    this.previewVisible = true;
                }, 25);
            }
        },
        onPreviewImageClick() {
            this.previewClick = true;
        },
        onMaskClick() {
            if (!this.previewClick) {
                this.previewVisible = false;
                this.rotate = 0;
                this.scale = 1;
            }

            this.previewClick = false;
        },
        rotateRight() {
            this.rotate += 90;
            this.previewClick = true;
        },
        rotateLeft() {
            this.rotate -= 90;
            this.previewClick = true;
        },
        zoomIn() {
            this.scale = this.scale + 0.1;
            this.previewClick = true;
        },
        zoomOut() {
            this.scale = this.scale - 0.1;
            this.previewClick = true;
        },
        onBeforeEnter() {
            ZIndexUtils.set('modal', this.mask, this.$primevue.config.zIndex.modal);
        },
        onEnter() {
            this.$emit('show');
        },
        onBeforeLeave() {
            DomHandler.addClass(this.mask, 'p-component-overlay-leave');
        },
        onLeave() {
            this.$emit('hide');
        },
        onAfterLeave(el) {
            ZIndexUtils.clear(el);
            this.maskVisible = false;
        }
    },
    computed: {
        containerClass() {
            return ['p-image p-component', this.class, {
                'p-image-preview-container': this.preview
            }];
        },
        maskClass() {
            return ['p-image-mask p-component-overlay p-component-overlay-enter'];
        },
        rotateClass() {
            return 'p-image-preview-rotate-' + this.rotate;
        },
        imagePreviewStyle() {
            return {transform: 'rotate(' + this.rotate + 'deg) scale(' + this.scale + ')'};
        },
        zoomDisabled() {
            return this.scale <= 0.5 || this.scale >= 1.5;
        }
    }
};

const _hoisted_1 = /*#__PURE__*/createVNode("i", { class: "p-image-preview-icon pi pi-eye" }, null, -1);
const _hoisted_2 = { class: "p-image-toolbar" };
const _hoisted_3 = /*#__PURE__*/createVNode("i", { class: "pi pi-refresh" }, null, -1);
const _hoisted_4 = /*#__PURE__*/createVNode("i", { class: "pi pi-undo" }, null, -1);
const _hoisted_5 = /*#__PURE__*/createVNode("i", { class: "pi pi-search-minus" }, null, -1);
const _hoisted_6 = /*#__PURE__*/createVNode("i", { class: "pi pi-search-plus" }, null, -1);
const _hoisted_7 = /*#__PURE__*/createVNode("i", { class: "pi pi-times" }, null, -1);
const _hoisted_8 = { key: 0 };

function render(_ctx, _cache, $props, $setup, $data, $options) {
  return (openBlock(), createBlock("span", {
    class: $options.containerClass,
    style: $props.style
  }, [
    createVNode("img", mergeProps(_ctx.$attrs, {
      style: $props.imageStyle,
      class: $props.imageClass
    }), null, 16),
    ($props.preview)
      ? (openBlock(), createBlock("div", {
          key: 0,
          class: "p-image-preview-indicator",
          onClick: _cache[1] || (_cache[1] = (...args) => ($options.onImageClick && $options.onImageClick(...args)))
        }, [
          renderSlot(_ctx.$slots, "indicator", {}, () => [
            _hoisted_1
          ])
        ]))
      : createCommentVNode("", true),
    (openBlock(), createBlock(Teleport, { to: "body" }, [
      ($data.maskVisible)
        ? (openBlock(), createBlock("div", {
            key: 0,
            ref: $options.maskRef,
            class: $options.maskClass,
            onClick: _cache[8] || (_cache[8] = (...args) => ($options.onMaskClick && $options.onMaskClick(...args)))
          }, [
            createVNode("div", _hoisted_2, [
              createVNode("button", {
                class: "p-image-action p-link",
                onClick: _cache[2] || (_cache[2] = (...args) => ($options.rotateRight && $options.rotateRight(...args))),
                type: "button"
              }, [
                _hoisted_3
              ]),
              createVNode("button", {
                class: "p-image-action p-link",
                onClick: _cache[3] || (_cache[3] = (...args) => ($options.rotateLeft && $options.rotateLeft(...args))),
                type: "button"
              }, [
                _hoisted_4
              ]),
              createVNode("button", {
                class: "p-image-action p-link",
                onClick: _cache[4] || (_cache[4] = (...args) => ($options.zoomOut && $options.zoomOut(...args))),
                type: "button",
                disabled: $options.zoomDisabled
              }, [
                _hoisted_5
              ], 8, ["disabled"]),
              createVNode("button", {
                class: "p-image-action p-link",
                onClick: _cache[5] || (_cache[5] = (...args) => ($options.zoomIn && $options.zoomIn(...args))),
                type: "button",
                disabled: $options.zoomDisabled
              }, [
                _hoisted_6
              ], 8, ["disabled"]),
              createVNode("button", {
                class: "p-image-action p-link",
                type: "button",
                onClick: _cache[6] || (_cache[6] = (...args) => (_ctx.hidePreview && _ctx.hidePreview(...args)))
              }, [
                _hoisted_7
              ])
            ]),
            createVNode(Transition, {
              name: "p-image-preview",
              onBeforeEnter: $options.onBeforeEnter,
              onEnter: $options.onEnter,
              onLeave: $options.onLeave,
              onBeforeLeave: $options.onBeforeLeave,
              onAfterLeave: $options.onAfterLeave
            }, {
              default: withCtx(() => [
                ($data.previewVisible)
                  ? (openBlock(), createBlock("div", _hoisted_8, [
                      createVNode("img", {
                        src: _ctx.$attrs.src,
                        class: "p-image-preview",
                        style: $options.imagePreviewStyle,
                        onClick: _cache[7] || (_cache[7] = (...args) => ($options.onPreviewImageClick && $options.onPreviewImageClick(...args)))
                      }, null, 12, ["src"])
                    ]))
                  : createCommentVNode("", true)
              ]),
              _: 1
            }, 8, ["onBeforeEnter", "onEnter", "onLeave", "onBeforeLeave", "onAfterLeave"])
          ], 2))
        : createCommentVNode("", true)
    ]))
  ], 6))
}

function styleInject(css, ref) {
  if ( ref === void 0 ) ref = {};
  var insertAt = ref.insertAt;

  if (!css || typeof document === 'undefined') { return; }

  var head = document.head || document.getElementsByTagName('head')[0];
  var style = document.createElement('style');
  style.type = 'text/css';

  if (insertAt === 'top') {
    if (head.firstChild) {
      head.insertBefore(style, head.firstChild);
    } else {
      head.appendChild(style);
    }
  } else {
    head.appendChild(style);
  }

  if (style.styleSheet) {
    style.styleSheet.cssText = css;
  } else {
    style.appendChild(document.createTextNode(css));
  }
}

var css_248z = "\n.p-image-mask {\n    display: -webkit-box;\n    display: -ms-flexbox;\n    display: flex;\n    -webkit-box-align: center;\n        -ms-flex-align: center;\n            align-items: center;\n    -webkit-box-pack: center;\n        -ms-flex-pack: center;\n            justify-content: center;\n}\n.p-image-preview-container {\n    position: relative;\n    display: inline-block;\n}\n.p-image-preview-indicator {\n    position: absolute;\n    left: 0;\n    top: 0;\n    width: 100%;\n    height: 100%;\n    display: -webkit-box;\n    display: -ms-flexbox;\n    display: flex;\n    -webkit-box-align: center;\n        -ms-flex-align: center;\n            align-items: center;\n    -webkit-box-pack: center;\n        -ms-flex-pack: center;\n            justify-content: center;\n    opacity: 0;\n    -webkit-transition: opacity .3s;\n    transition: opacity .3s;\n}\n.p-image-preview-icon {\n    font-size: 1.5rem;\n}\n.p-image-preview-container:hover > .p-image-preview-indicator {\n    opacity: 1;\n    cursor: pointer;\n}\n.p-image-preview-container > img {\n    cursor: pointer;\n}\n.p-image-toolbar {\n    position: absolute;\n    top: 0;\n    right: 0;\n    display: -webkit-box;\n    display: -ms-flexbox;\n    display: flex;\n}\n.p-image-action.p-link {\n    display: -webkit-box;\n    display: -ms-flexbox;\n    display: flex;\n    -webkit-box-pack: center;\n        -ms-flex-pack: center;\n            justify-content: center;\n    -webkit-box-align: center;\n        -ms-flex-align: center;\n            align-items: center;\n}\n.p-image-preview {\n    -webkit-transition: -webkit-transform .15s;\n    transition: -webkit-transform .15s;\n    transition: transform .15s;\n    transition: transform .15s, -webkit-transform .15s;\n    max-width: 100vw;\n    max-height: 100vh;\n}\n.p-image-preview-enter-active {\n    -webkit-transition: all 150ms cubic-bezier(0, 0, 0.2, 1);\n    transition: all 150ms cubic-bezier(0, 0, 0.2, 1);\n}\n.p-image-preview-leave-active {\n    -webkit-transition: all 150ms cubic-bezier(0.4, 0.0, 0.2, 1);\n    transition: all 150ms cubic-bezier(0.4, 0.0, 0.2, 1);\n}\n.p-image-preview-enter-from,\n.p-image-preview-leave-to {\n    opacity: 0;\n    -webkit-transform: scale(0.7);\n            transform: scale(0.7);\n}\n";
styleInject(css_248z);

script.render = render;

export default script;
