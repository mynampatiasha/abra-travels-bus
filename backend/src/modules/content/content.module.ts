import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { RbacModule } from '../rbac/rbac.module';
import { UsersModule } from '../users/users.module';
import { ContentAdminController, ContentPublicController } from './content_admin_manage';
import {
  CONTENT_CONTACT_MODEL,
  CONTENT_FAQ_MODEL,
  CONTENT_PAGE_MODEL,
  ContentService,
  contentContactSchema,
  contentFaqSchema,
  contentPageSchema,
} from './content_admin_manage.service';

/**
 * `content`: the information pages, the FAQs and the contact details. Admin writes under
 * `/admin/content`, everyone reads under `/content` (no sign-in).
 */
@Module({
  imports: [
    MongooseModule.forFeature([
      { name: CONTENT_PAGE_MODEL, schema: contentPageSchema },
      { name: CONTENT_FAQ_MODEL, schema: contentFaqSchema },
      { name: CONTENT_CONTACT_MODEL, schema: contentContactSchema },
    ]),
    RbacModule,
    UsersModule,
  ],
  controllers: [ContentPublicController, ContentAdminController],
  providers: [ContentService],
  exports: [ContentService],
})
export class ContentModule {}
