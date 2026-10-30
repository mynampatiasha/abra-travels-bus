import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type Model, Schema, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { escapeRegExp, skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import { UsersService } from '../users/services/users.service';

/*
 * Help content (admin writes, everyone reads): the information pages (terms, privacy, about), the
 * FAQs and the contact details. The customer app and the website read the published ones through
 * the public endpoints; staff with content.manage change them and every change is audited.
 */

export const CONTENT_PAGE_MODEL = 'ContentPage';
export const CONTENT_FAQ_MODEL = 'ContentFaq';
export const CONTENT_CONTACT_MODEL = 'ContentContact';

export const PAGE_KEYS = ['terms', 'privacy', 'about'] as const;
export type PageKey = (typeof PAGE_KEYS)[number];
export const CONTENT_STATUSES = ['DRAFT', 'PUBLISHED'] as const;
export type ContentStatus = (typeof CONTENT_STATUSES)[number];

export const MAX_TITLE_LENGTH = 120;
export const MAX_BODY_LENGTH = 50_000;
export const MAX_QUESTION_LENGTH = 300;
export const MAX_ANSWER_LENGTH = 5_000;
export const MAX_CATEGORY_LENGTH = 60;

// ===== 1. STORED DOCUMENTS =====

export interface ContentPage {
  key: PageKey;
  title: string;
  body: string;
  status: ContentStatus;
  updatedBy: Types.ObjectId;
  updatedByName: string;
  createdAt?: Date;
  updatedAt?: Date;
}
export type StoredContentPage = ContentPage & { _id: Types.ObjectId };

export interface ContentFaq {
  question: string;
  answer: string;
  category: string;
  /** Position in the list; smaller comes first. */
  order: number;
  status: ContentStatus;
  updatedBy: Types.ObjectId;
  deletedAt: Date | null;
  createdAt?: Date;
  updatedAt?: Date;
}
export type StoredContentFaq = ContentFaq & { _id: Types.ObjectId };

/** The support contact details: a single document. */
export interface ContentContact {
  phone: string;
  email: string;
  address: string;
  hours: string;
  updatedBy: Types.ObjectId;
  createdAt?: Date;
  updatedAt?: Date;
}
export type StoredContentContact = ContentContact & { _id: Types.ObjectId };

/** `content_pages`. */
export const contentPageSchema = new Schema<ContentPage>(
  {
    key: { type: String, enum: PAGE_KEYS, required: true },
    title: { type: String, required: true, maxlength: MAX_TITLE_LENGTH },
    body: { type: String, default: '', maxlength: MAX_BODY_LENGTH },
    status: { type: String, enum: CONTENT_STATUSES, required: true },
    updatedBy: { type: Schema.Types.ObjectId, required: true },
    updatedByName: { type: String, default: '', maxlength: 120 },
  },
  { collection: 'content_pages', timestamps: true, versionKey: false },
);
contentPageSchema.index({ key: 1 }, { unique: true });

/** `content_faqs`. */
export const contentFaqSchema = new Schema<ContentFaq>(
  {
    question: { type: String, required: true, maxlength: MAX_QUESTION_LENGTH },
    answer: { type: String, required: true, maxlength: MAX_ANSWER_LENGTH },
    category: { type: String, default: 'General', maxlength: MAX_CATEGORY_LENGTH },
    order: { type: Number, default: 0 },
    status: { type: String, enum: CONTENT_STATUSES, required: true },
    updatedBy: { type: Schema.Types.ObjectId, required: true },
    deletedAt: { type: Date, default: null },
  },
  { collection: 'content_faqs', timestamps: true, versionKey: false },
);
contentFaqSchema.index({ deletedAt: 1, status: 1, order: 1 });

/** `content_contact`: holds at most one document. */
export const contentContactSchema = new Schema<ContentContact>(
  {
    phone: { type: String, default: '', maxlength: 40 },
    email: { type: String, default: '', maxlength: 160 },
    address: { type: String, default: '', maxlength: 400 },
    hours: { type: String, default: '', maxlength: 200 },
    updatedBy: { type: Schema.Types.ObjectId, required: true },
  },
  { collection: 'content_contact', timestamps: true, versionKey: false },
);

// ===== 2. VIEWS =====

export interface PageView {
  key: PageKey;
  title: string;
  body: string;
  status: ContentStatus;
  updatedBy: string;
  updatedAt: string | null;
}

/** What a customer or a visitor sees: no staff name, only published pages. */
export interface PublicPageView {
  key: PageKey;
  title: string;
  body: string;
  updatedAt: string | null;
}

export interface FaqView {
  id: string;
  question: string;
  answer: string;
  category: string;
  order: number;
  status: ContentStatus;
  updatedAt: string | null;
}

export interface ContactView {
  configured: boolean;
  phone: string;
  email: string;
  address: string;
  hours: string;
  updatedAt: string | null;
}

export interface PageInput {
  title: string;
  body: string;
  status: ContentStatus;
}

export interface FaqInput {
  question: string;
  answer: string;
  category?: string | undefined;
  order?: number | undefined;
  status: ContentStatus;
}

export interface ContactInput {
  phone: string;
  email: string;
  address: string;
  hours: string;
}

export interface FaqListQuery {
  search?: string | undefined;
  status?: ContentStatus | undefined;
  category?: string | undefined;
  page: number;
  pageSize: number;
}

/** The titles an empty page shows in the admin list, until staff write the first version. */
const DEFAULT_TITLES: Readonly<Record<PageKey, string>> = {
  terms: 'Terms and conditions',
  privacy: 'Privacy policy',
  about: 'About Abra',
};

const iso = (date: Date | undefined): string | null => (date ? date.toISOString() : null);

function fieldError(path: string, message: string): ApiException {
  return new ApiException('VALIDATION_FAILED', 'Request validation failed', {
    location: 'body',
    issues: [{ path, code: 'custom', message }],
  });
}

function pageViewOf(page: StoredContentPage): PageView {
  return {
    key: page.key,
    title: page.title,
    body: page.body,
    status: page.status,
    updatedBy: page.updatedByName,
    updatedAt: iso(page.updatedAt),
  };
}

function faqViewOf(faq: StoredContentFaq): FaqView {
  return {
    id: faq._id.toHexString(),
    question: faq.question,
    answer: faq.answer,
    category: faq.category,
    order: faq.order,
    status: faq.status,
    updatedAt: iso(faq.updatedAt),
  };
}

function contactViewOf(contact: StoredContentContact | null): ContactView {
  return {
    configured: contact !== null,
    phone: contact?.phone ?? '',
    email: contact?.email ?? '',
    address: contact?.address ?? '',
    hours: contact?.hours ?? '',
    updatedAt: iso(contact?.updatedAt),
  };
}

// ===== 3. THE SERVICE =====

@Injectable()
export class ContentService {
  constructor(
    @InjectModel(CONTENT_PAGE_MODEL) private readonly pages: Model<ContentPage>,
    @InjectModel(CONTENT_FAQ_MODEL) private readonly faqs: Model<ContentFaq>,
    @InjectModel(CONTENT_CONTACT_MODEL) private readonly contact: Model<ContentContact>,
    private readonly changes: AuditedChangeRunner,
    private readonly users: UsersService,
  ) {}

  // ----- public reading -----

  async publicPage(key: PageKey): Promise<PublicPageView> {
    const page = await this.pages
      .findOne({ key, status: 'PUBLISHED' })
      .lean<StoredContentPage>()
      .exec();
    if (!page) throw new ApiException('RESOURCE_NOT_FOUND', 'This page is not published yet.');
    return { key: page.key, title: page.title, body: page.body, updatedAt: iso(page.updatedAt) };
  }

  async publicFaqs(category: string | undefined): Promise<FaqView[]> {
    const filter: Record<string, unknown> = { deletedAt: null, status: 'PUBLISHED' };
    if (category?.trim()) filter.category = category.trim();
    const found = await this.faqs
      .find(filter)
      .sort({ order: 1, _id: 1 })
      .lean<StoredContentFaq[]>()
      .exec();
    return found.map(faqViewOf);
  }

  async publicContact(): Promise<ContactView> {
    return contactViewOf(await this.contact.findOne().lean<StoredContentContact>().exec());
  }

  // ----- admin reading -----

  /** All three pages, written or not: a page nobody wrote yet shows as an empty draft. */
  async listPages(): Promise<PageView[]> {
    const stored = await this.pages.find().lean<StoredContentPage[]>().exec();
    return PAGE_KEYS.map((key) => {
      const page = stored.find((item) => item.key === key);
      return page
        ? pageViewOf(page)
        : { key, title: DEFAULT_TITLES[key], body: '', status: 'DRAFT', updatedBy: '', updatedAt: null };
    });
  }

  async getPage(key: PageKey): Promise<PageView> {
    const found = (await this.listPages()).find((page) => page.key === key);
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'This page does not exist.');
    return found;
  }

  async listFaqs(query: FaqListQuery): Promise<PaginatedResult<FaqView>> {
    const filter: Record<string, unknown> = { deletedAt: null };
    if (query.status) filter.status = query.status;
    if (query.category) filter.category = query.category;
    const text = query.search?.trim();
    if (text) {
      const pattern = { $regex: escapeRegExp(text), $options: 'i' };
      filter.$or = [{ question: pattern }, { answer: pattern }];
    }
    const [items, total] = await Promise.all([
      this.faqs
        .find(filter)
        .sort({ order: 1, _id: 1 })
        .skip(skipOf(query))
        .limit(query.pageSize)
        .lean<StoredContentFaq[]>()
        .exec(),
      this.faqs.countDocuments(filter).exec(),
    ]);
    return new PaginatedResult(items.map(faqViewOf), query.page, query.pageSize, total);
  }

  async getContact(): Promise<ContactView> {
    return this.publicContact();
  }

  // ----- admin changes -----

  async savePage(
    actor: AuthenticatedUserActor,
    key: PageKey,
    input: PageInput,
    client: ClientRequestInfo,
  ): Promise<PageView> {
    const title = input.title.trim();
    if (!title) throw fieldError('title', 'Enter a title');
    if (input.status === 'PUBLISHED' && !input.body.trim()) {
      throw fieldError('body', 'Write the page before you publish it');
    }
    const who = await this.whoIs(actor);
    const existing = await this.pages.findOne({ key }).lean<StoredContentPage>().exec();
    const saved = await this.changes.run({
      actor,
      client,
      action: 'content.page.saved',
      entityType: 'content-page',
      before: existing ? this.describePage(existing) : {},
      apply: async (session) => {
        const stored = await this.pages
          .findOneAndUpdate(
            { key },
            {
              $set: {
                title,
                body: input.body,
                status: input.status,
                updatedBy: who.id,
                updatedByName: who.name,
              },
            },
            { returnDocument: 'after', upsert: true, session },
          )
          .lean<StoredContentPage>()
          .exec();
        if (!stored) throw new Error('Page was not saved');
        return stored;
      },
      describe: (page) => this.describePage(page),
    });
    return pageViewOf(saved);
  }

  async createFaq(
    actor: AuthenticatedUserActor,
    input: FaqInput,
    client: ClientRequestInfo,
  ): Promise<FaqView> {
    const clean = this.cleanFaq(input);
    const who = await this.whoIs(actor);
    const order =
      clean.order ??
      ((await this.faqs.findOne({ deletedAt: null }).sort({ order: -1 }).lean<StoredContentFaq>().exec())
        ?.order ?? 0) + 1;
    const created = await this.changes.run({
      actor,
      client,
      action: 'content.faq.created',
      entityType: 'content-faq',
      before: {},
      apply: async (session) => {
        const [faq] = await this.faqs.create(
          [{ ...clean, order, updatedBy: who.id, deletedAt: null }],
          { session },
        );
        if (!faq) throw new Error('FAQ was not created');
        return faq.toObject() as StoredContentFaq;
      },
      describe: (faq) => this.describeFaq(faq),
    });
    return faqViewOf(created);
  }

  async updateFaq(
    actor: AuthenticatedUserActor,
    id: string,
    input: FaqInput,
    client: ClientRequestInfo,
  ): Promise<FaqView> {
    const clean = this.cleanFaq(input);
    const before = await this.liveFaq(id);
    const who = await this.whoIs(actor);
    const updated = await this.changes.run({
      actor,
      client,
      action: 'content.faq.updated',
      entityType: 'content-faq',
      before: this.describeFaq(before),
      apply: async (session) => {
        const stored = await this.faqs
          .findOneAndUpdate(
            { _id: before._id, deletedAt: null },
            { $set: { ...clean, order: clean.order ?? before.order, updatedBy: who.id } },
            { returnDocument: 'after', session },
          )
          .lean<StoredContentFaq>()
          .exec();
        if (!stored) throw new ApiException('RESOURCE_NOT_FOUND', 'This question no longer exists.');
        return stored;
      },
      describe: (faq) => this.describeFaq(faq),
    });
    return faqViewOf(updated);
  }

  async removeFaq(
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<FaqView> {
    const before = await this.liveFaq(id);
    const who = await this.whoIs(actor);
    const removed = await this.changes.run({
      actor,
      client,
      action: 'content.faq.deleted',
      entityType: 'content-faq',
      before: this.describeFaq(before),
      apply: async (session) => {
        const stored = await this.faqs
          .findOneAndUpdate(
            { _id: before._id, deletedAt: null },
            { $set: { deletedAt: new Date(), updatedBy: who.id } },
            { returnDocument: 'after', session },
          )
          .lean<StoredContentFaq>()
          .exec();
        if (!stored) throw new ApiException('RESOURCE_NOT_FOUND', 'This question no longer exists.');
        return stored;
      },
      describe: (faq) => ({ ...this.describeFaq(faq), deleted: true }),
    });
    return faqViewOf(removed);
  }

  async saveContact(
    actor: AuthenticatedUserActor,
    input: ContactInput,
    client: ClientRequestInfo,
  ): Promise<ContactView> {
    const clean = {
      phone: input.phone.trim(),
      email: input.email.trim(),
      address: input.address.trim(),
      hours: input.hours.trim(),
    };
    if (!clean.phone && !clean.email) {
      throw fieldError('phone', 'Enter at least a phone number or an email address');
    }
    const who = await this.whoIs(actor);
    const existing = await this.contact.findOne().lean<StoredContentContact>().exec();
    const saved = await this.changes.run({
      actor,
      client,
      action: 'content.contact.saved',
      entityType: 'content-contact',
      before: existing ? this.describeContact(existing) : {},
      apply: async (session) => {
        const stored = await this.contact
          .findOneAndUpdate(
            {},
            { $set: { ...clean, updatedBy: who.id } },
            { returnDocument: 'after', upsert: true, session },
          )
          .lean<StoredContentContact>()
          .exec();
        if (!stored) throw new Error('Contact details were not saved');
        return stored;
      },
      describe: (contact) => this.describeContact(contact),
    });
    return contactViewOf(saved);
  }

  // ----- helpers -----

  private cleanFaq(input: FaqInput): {
    question: string;
    answer: string;
    category: string;
    order: number | undefined;
    status: ContentStatus;
  } {
    const question = input.question.trim();
    const answer = input.answer.trim();
    if (!question) throw fieldError('question', 'Enter the question');
    if (!answer) throw fieldError('answer', 'Enter the answer');
    return {
      question,
      answer,
      category: input.category?.trim() || 'General',
      order: input.order,
      status: input.status,
    };
  }

  private async liveFaq(id: string): Promise<StoredContentFaq> {
    const faq = Types.ObjectId.isValid(id)
      ? await this.faqs
          .findOne({ _id: new Types.ObjectId(id), deletedAt: null })
          .lean<StoredContentFaq>()
          .exec()
      : null;
    if (!faq) throw new ApiException('RESOURCE_NOT_FOUND', 'This question no longer exists.');
    return faq;
  }

  private async whoIs(
    actor: AuthenticatedUserActor,
  ): Promise<{ id: Types.ObjectId; name: string }> {
    const id = new Types.ObjectId(actor.userId);
    const [found] = await this.users.findNames([id]);
    return { id, name: found?.name?.trim() || 'Staff' };
  }

  /** What the audit trail keeps: the page name and its state, not the whole text. */
  private describePage(page: StoredContentPage): Record<string, unknown> {
    return {
      name: page.title,
      key: page.key,
      status: page.status,
      length: page.body.length,
    };
  }

  private describeFaq(faq: StoredContentFaq): Record<string, unknown> {
    return {
      name: faq.question,
      category: faq.category,
      order: faq.order,
      status: faq.status,
    };
  }

  private describeContact(contact: StoredContentContact): Record<string, unknown> {
    return {
      name: 'Contact details',
      phone: contact.phone,
      email: contact.email,
      address: contact.address,
      hours: contact.hours,
    };
  }
}
