// 敏感資料驗證 JavaScript
(function($) {
  'use strict';

  // 敏感資料偵測模式
  const SENSITIVE_PATTERNS = {
    taiwan_id: {
      regex: /[A-Z][12]\d{8}/g,
      description: '台灣身分證號碼',
      risk_level: 'high'
    },
    credit_card: {
      regex: /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/g,
      description: '信用卡號碼',
      risk_level: 'high'
    },
    taiwan_mobile: {
      regex: /\b09\d{8}\b/g,
      description: '台灣手機號碼',
      risk_level: 'medium'
    },
    password_keywords: {
      regex: /(password|pwd|passwd|secret|key|token|api.?key|auth)/gi,
      description: '密碼或金鑰關鍵字',
      risk_level: 'high'
    },
    username_password: {
      regex: /(user(?:name|id)?|login|account)\s*[:=]\s*['"]?[^'"\s]+['"]?\s*(password|pwd|pass)\s*[:=]\s*['"]?[^'"\s]{6,}['"]?/gi,
      description: '帳號密碼組合',
      risk_level: 'critical'
    },
    ip_address: {
      regex: /\b(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)\d{1,3}\.\d{1,3}\b/g,
      description: '內部 IP 位址',
      risk_level: 'medium'
    },
    email_address: {
      regex: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g,
      description: 'Email 地址',
      risk_level: 'low'
    },
    database_connection: {
      regex: /(mysql|postgresql|mongodb|redis):\/\/[^'"\s]+/gi,
      description: '資料庫連線字串',
      risk_level: 'high'
    }
  };

  // 敏感資料驗證類別
  class SensitiveDataValidator {
    constructor() {
      this.warningElement = null;
      this.detectionResults = [];
      this.init();
    }

    init() {
      try {
        this.createWarningElement();
        this.bindEvents();
        this.setupFormValidation();
      } catch (error) {
        console.error('敏感資料驗證初始化失敗:', error);
      }
    }

    createWarningElement() {
      try {
        // 檢查是否已存在警告元素
        if ($('.sensitive-data-warning').length === 0) {
          const warningHtml = `
            <div class="sensitive-data-warning" style="display: none;">
              <div class="warning-message">
                <i class="icon icon-warning"></i>
                <span>檢測到敏感資料，請確認內容後再提交。</span>
                <div class="detection-details"></div>
              </div>
            </div>
          `;
          $('body').append(warningHtml);
        }
        this.warningElement = $('.sensitive-data-warning');
      } catch (error) {
        console.error('創建警告元素失敗:', error);
      }
    }

    bindEvents() {
      try {
        // 監聽表單輸入事件
        $(document).on('input', 'textarea, input[type="text"], input[type="email"]', (e) => {
          this.validateContent($(e.target));
        });

        // 監聽表單提交事件
        $(document).on('submit', 'form', (e) => {
          if (!this.validateForm($(e.target))) {
            e.preventDefault();
            return false;
          }
        });

        // 監聽富文本編輯器
        if (typeof CKEDITOR !== 'undefined') {
          CKEDITOR.on('instanceReady', (evt) => {
            evt.editor.on('change', () => {
              this.validateContent($(evt.editor.element.$));
            });
          });
        }
      } catch (error) {
        console.error('綁定事件失敗:', error);
      }
    }

    setupFormValidation() {
      // 為常見的表單添加驗證
      const forms = [
        '#issue-form',
        '#wiki-form',
        '#message-form',
        '#news-form'
      ];

      forms.forEach(formSelector => {
        if ($(formSelector).length > 0) {
          this.addFormValidation($(formSelector));
        }
      });
    }

    addFormValidation(form) {
      const textFields = form.find('textarea, input[type="text"], input[type="email"]');
      textFields.each((index, field) => {
        $(field).on('input', () => {
          this.validateContent($(field));
        });
      });
    }

    validateContent(element) {
      const content = element.val() || element.text();
      if (!content) {
        this.hideWarning();
        return true;
      }

      this.detectionResults = this.scanContent(content);
      
      if (this.detectionResults.length > 0) {
        this.showWarning(this.detectionResults);
        return false;
      } else {
        this.hideWarning();
        return true;
      }
    }

    validateForm(form) {
      let isValid = true;
      const textFields = form.find('textarea, input[type="text"], input[type="email"]');
      
      textFields.each((index, field) => {
        if (!this.validateContent($(field))) {
          isValid = false;
        }
      });

      return isValid;
    }

    scanContent(content) {
      const results = [];
      
      Object.keys(SENSITIVE_PATTERNS).forEach(patternKey => {
        const pattern = SENSITIVE_PATTERNS[patternKey];
        const matches = content.match(pattern.regex);
        
        if (matches) {
          results.push({
            pattern: patternKey,
            description: pattern.description,
            risk_level: pattern.risk_level,
            matches: matches,
            count: matches.length
          });
        }
      });

      return results;
    }

    showWarning(results) {
      if (this.warningElement) {
        const detailsHtml = this.generateDetailsHtml(results);
        this.warningElement.find('.detection-details').html(detailsHtml);
        this.warningElement.show();
        
        // 滾動到警告位置
        this.warningElement[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    }

    hideWarning() {
      if (this.warningElement) {
        this.warningElement.hide();
      }
    }

    generateDetailsHtml(results) {
      let html = '<ul class="detection-list">';
      
      results.forEach(result => {
        const riskClass = `risk-${result.risk_level}`;
        html += `
          <li class="${riskClass}">
            <strong>${result.description}</strong>: 發現 ${result.count} 個匹配
            <div class="matches-preview">
              ${this.maskSensitiveData(result.matches.slice(0, 3).join(', '))}
            </div>
          </li>
        `;
      });
      
      html += '</ul>';
      return html;
    }

    maskSensitiveData(text) {
      if (!text) return '';
      
      return text
        .replace(/([A-Z][12]\d{5})\d{3}/g, '$1***')  // 身分證號
        .replace(/(\d{4}[\s-]?\d{4}[\s-]?\d{4})[\s-]?\d{4}/g, '$1-****')  // 信用卡號
        .replace(/(09\d{4})\d{4}/g, '$1****')  // 手機號碼
        .replace(/([A-Za-z0-9._%+-]+)@([A-Za-z0-9.-]+\.[A-Z|a-z]{2,})/g, (match, username, domain) => {
          return `${username[0]}***@${domain}`;  // Email
        });
    }

    getDetectionResults() {
      return this.detectionResults;
    }
  }

  // 初始化驗證器
  $(document).ready(function() {
    window.sensitiveDataValidator = new SensitiveDataValidator();
  });

})(jQuery);
