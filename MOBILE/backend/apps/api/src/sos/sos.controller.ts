import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Query,
  Body,
  UseGuards,
} from '@nestjs/common';
import { SosService } from './sos.service';
import { CreateSosDto } from './dto/create-sos.dto';
import { FirebaseAuthGuard, RolesGuard, Roles } from '@rihlah/firebase';

@Controller('sos')
@UseGuards(FirebaseAuthGuard)
export class SosController {
  constructor(private readonly sosService: SosService) {}

  /** Trigger an SOS event. */
  @Post()
  async trigger(@Body() dto: CreateSosDto) {
    return this.sosService.trigger(dto);
  }

  /** Get an upload URL for SOS audio recording. */
  @Get(':id/upload-url')
  async getUploadUrl(@Param('id') id: string) {
    return { url: await this.sosService.getAudioUploadUrl(id) };
  }

  /** Admin: list all SOS events. */
  @Get()
  @Roles('admin')
  @UseGuards(RolesGuard)
  async findAll(
    @Query('status') status?: string,
    @Query('limit') limit?: number,
    @Query('offset') offset?: number,
  ) {
    return this.sosService.findAll({ status, limit, offset });
  }

  /** Admin: acknowledge an SOS event. */
  @Patch(':id/acknowledge')
  @Roles('admin')
  @UseGuards(RolesGuard)
  async acknowledge(
    @Param('id') id: string,
    @Body('adminId') adminId: string,
  ) {
    return this.sosService.acknowledge(id, adminId);
  }
}
